
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/nubi/nubi_service.dart';

const nubiBlue = Color(0xFF29B6F6);

void nubiOpen(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => page),
  );
}

void nubiMessage(BuildContext context, Object message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message.toString())),
  );
}

Widget nubiPage(
    String title,
    Widget body,
    ) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(child: body),
  );
}

Widget nubiEmpty(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

// ===========================================
// BATCH 5: MY DECK
// ===========================================

class NubiDeckScreen extends StatelessWidget {
  const NubiDeckScreen({
    super.key,
    this.initialTab = 0,
  });

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Deck'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Continue Learning'),
              Tab(text: 'AI Sessions'),
              Tab(text: 'Flashcards'),
              Tab(text: 'MCQs'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AllTab(),
            _SourcesTab(unfinishedOnly: true),
            _SessionsTab(),
            _DecksTab(),
            _QuizzesTab(),
            _SourcesTab(completedOnly: true),
          ],
        ),
      ),
    );
  }
}

// ===========================================
// ALL: LECTURES + AI CHAT HISTORY
// ===========================================

class _AllTab extends StatefulWidget {
  const _AllTab();

  @override
  State<_AllTab> createState() => _AllTabState();
}

class _AllTabState extends State<_AllTab> {
  // Kept in state so the nested builders don't resubscribe on every
  // snapshot of the other stream.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _sources =
  NubiService.sources
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _sessions =
  NubiService.sessions
      .orderBy('lastActivity', descending: true)
      .limit(30)
      .snapshots();

  // Pending server timestamps are null; treat them as newest.
  static DateTime _time(Object? value) {
    return value is Timestamp ? value.toDate() : DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _sources,
      builder: (context, sourceSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _sessions,
          builder: (context, sessionSnap) {
            if (sourceSnap.hasError || sessionSnap.hasError) {
              return nubiEmpty(
                'Unable to read your deck.',
              );
            }

            if (!sourceSnap.hasData || !sessionSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final items = <({DateTime time, Widget tile})>[
              for (final doc in sourceSnap.data!.docs)
                if (doc.data()['status'] == 'ready')
                  (
                  time: _time(doc.data()['createdAt']),
                  tile: _SourceCard(doc: doc),
                  ),
              for (final doc in sessionSnap.data!.docs)
                (
                time: _time(doc.data()['lastActivity']),
                tile: Card(child: _SessionTile(doc: doc)),
                ),
            ]..sort((a, b) => b.time.compareTo(a.time));

            if (items.isEmpty) {
              return nubiEmpty(
                'Nothing here yet. Upload a lecture '
                    'or ask NUBi a question to get started.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              itemBuilder: (context, index) => items[index].tile,
            );
          },
        );
      },
    );
  }
}

class _SourcesTab extends StatelessWidget {
  const _SourcesTab({
    this.unfinishedOnly = false,
    this.completedOnly = false,
  });

  final bool unfinishedOnly;
  final bool completedOnly;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NubiService.sources
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return nubiEmpty(
            'Unable to read your saved lectures.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();

          if (data['status'] != 'ready') {
            return false;
          }

          final total = data['totalSections'] ?? 0;
          final completed =
              (data['completedSections'] as List?)
                  ?.length ?? 0;

          if (unfinishedOnly) {
            return completed < total;
          }

          if (completedOnly) {
            return total > 0 && completed >= total;
          }

          return true;
        }).toList();

        if (docs.isEmpty) {
          return nubiEmpty(
            'No lectures here yet. Upload '
                'a lecture from NUBi to get started.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (context, index) =>
              _SourceCard(doc: docs[index]),
        );
      },
    );
  }
}

// ===========================================
// SAVED LECTURE CARD
// ===========================================

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  Future<void> _delete(
      BuildContext context,
      String sourceId,
      ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this lecture?'),
        content: const Text(
          'Associated AI sessions, generated '
              'flashcards and quizzes will be deleted. '
              'Earned XP will remain in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (approved != true) return;

    try {
      await NubiService.deleteSource(sourceId);
      if (context.mounted) {
        nubiMessage(context, 'Lecture deleted.');
      }
    } catch (error) {
      if (context.mounted) {
        nubiMessage(context, error);
      }
    }
  }

  Future<void> _generateQuiz(
      BuildContext context,
      String sourceId,
      ) async {
    final count = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('How many MCQs?'),
        children: [5, 7, 10, 12, 15]
            .map(
              (count) => SimpleDialogOption(
            onPressed: () => Navigator.pop(
              dialogContext, count,
            ),
            child: Text('$count questions'),
          ),
        )
            .toList(),
      ),
    );

    if (count == null || !context.mounted) return;

    try {
      nubiMessage(
        context,
        'Generating $count questions...',
      );

      final data = await NubiService.createQuiz(
        sourceId, count,
      );

      if (context.mounted) {
        nubiOpen(
          context,
          NubiQuizRunScreen(
            quizId: data['quizId'].toString(),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        nubiMessage(context, error);
      }
    }
  }

  Future<void> _generateCards(
      BuildContext context,
      String sourceId,
      ) async {
    try {
      nubiMessage(
        context,
        'Generating flashcards...',
      );

      final data =
      await NubiService.createFlashcards(sourceId);

      if (context.mounted) {
        nubiOpen(
          context,
          NubiFlashcardsRunScreen(
            deckId: data['deckId'].toString(),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        nubiMessage(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final completed =
        (data['completedSections'] as List?)
            ?.length ?? 0;
    final total =
        (data['totalSections'] as num?)?.toInt()
            ?? 0;

    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.menu_book_rounded,
          color: nubiBlue,
        ),
        title: Text(
          (data['title'] ?? 'Lecture').toString(),
        ),
        subtitle: Text(
          '$completed/$total sections completed',
        ),
        onTap: () => nubiOpen(
          context,
          NubiTutorScreen(sourceId: doc.id),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'quiz') {
              _generateQuiz(context, doc.id);
            } else if (action == 'cards') {
              _generateCards(context, doc.id);
            } else if (action == 'delete') {
              _delete(context, doc.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'quiz',
              child: Text('Generate MCQs'),
            ),
            PopupMenuItem(
              value: 'cards',
              child: Text('Generate Flashcards'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete Lecture'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================
// SAVED AI SESSIONS
// ===========================================

class _SessionsTab extends StatelessWidget {
  const _SessionsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NubiService.sessions
          .orderBy('lastActivity', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return nubiEmpty('No AI sessions yet.');
        }

        return ListView(
          children: docs
              .map((doc) => _SessionTile(doc: doc))
              .toList(),
        );
      },
    );
  }
}

// ===========================================
// SAVED AI SESSION TILE
// ===========================================

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final sourceId =
    (data['sourceId'] ?? '').toString();

    return ListTile(
      leading: const Icon(Icons.smart_toy_outlined),
      title: Text(
        (data['title'] ?? 'NUBi Session')
            .toString(),
      ),
      subtitle: Text(
        (data['lastAnswer'] ?? '').toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => nubiOpen(
        context,
        NubiTutorScreen(
          sourceId: sourceId.isEmpty
              ? null : sourceId,
          existingSessionId: doc.id,
        ),
      ),
    );
  }
}

// ===========================================
// SAVED FLASHCARD DECKS
// ===========================================

class _DecksTab extends StatelessWidget {
  const _DecksTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NubiService.decks
          .orderBy('createdAt', descending: true)
          .limit(40)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return nubiEmpty(
            'No flashcards yet. Open a lecture '
                'and choose Generate Flashcards.',
          );
        }

        return ListView(
          children: docs.map((doc) => ListTile(
            leading: const Icon(
              Icons.style_rounded,
              color: Color(0xFF14B8A6),
            ),
            title: Text(
              (doc.data()['title'] ?? 'Deck')
                  .toString(),
            ),
            subtitle: Text(
              '${(doc.data()['cards'] as List?)?.length ?? 0} cards',
            ),
            onTap: () => nubiOpen(
              context,
              NubiFlashcardsRunScreen(deckId: doc.id),
            ),
          )).toList(),
        );
      },
    );
  }
}

// ===========================================
// SAVED QUIZZES
// ===========================================

class _QuizzesTab extends StatelessWidget {
  const _QuizzesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NubiService.quizzes
          .orderBy('createdAt', descending: true)
          .limit(40)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return nubiEmpty(
            'No quizzes yet. Generate MCQs '
                'from one of your lectures.',
          );
        }

        return ListView(
          children: docs.map((doc) => ListTile(
            leading: const Icon(
              Icons.quiz_rounded,
              color: Color(0xFF4338CA),
            ),
            title: Text(
              (doc.data()['title'] ?? 'Quiz')
                  .toString(),
            ),
            subtitle: Text(
              '${doc.data()['count'] ?? 0} questions',
            ),
            onTap: () => nubiOpen(
              context,
              NubiQuizRunScreen(quizId: doc.id),
            ),
          )).toList(),
        );
      },
    );
  }
}

// ===========================================
// BATCH 4: INTERACTIVE AI TUTOR
// ===========================================

class NubiTutorScreen extends StatefulWidget {
  const NubiTutorScreen({
    super.key,
    this.sourceId,
    this.initialQuestion,
    this.existingSessionId,
  });

  final String? sourceId;
  final String? initialQuestion;
  final String? existingSessionId;

  @override
  State<NubiTutorScreen> createState() =>
      _NubiTutorScreenState();
}

class _NubiTutorScreenState
    extends State<NubiTutorScreen> {
  final TextEditingController _question =
  TextEditingController();

  String? _sessionId;
  Map<String, dynamic>? _source;
  Map<String, dynamic>? _checkpoint;
  Map<String, dynamic>? _feedback;

  int _sectionIndex = 0;
  bool _busy = false;

  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _sessionId = widget.existingSessionId;
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.sourceId != null) {
      try {
        final doc = await NubiService.sources
            .doc(widget.sourceId)
            .get();

        if (!mounted) return;

        setState(() {
          _source = doc.data();
          _sectionIndex =
              (_source?['currentSection'] as num?)
                  ?.toInt() ?? 0;
        });
      } catch (error) {
        if (mounted) nubiMessage(context, error);
      }
    }

    if (_sessionId != null) {
      try {
        final messages = await NubiService.sessions
            .doc(_sessionId)
            .collection('messages')
            .orderBy('createdAt')
            .limit(40)
            .get();

        if (mounted) {
          setState(() {
            _messages.addAll(
              messages.docs.map((doc) => {
                'role': (doc.data()['role'] ?? '').toString(),
                'text': (doc.data()['text'] ?? '').toString(),
              }),
            );
          });
        }
      } catch (error) {
        if (mounted) nubiMessage(context, error);
      }
    }

    if (widget.initialQuestion != null) {
      _question.text = widget.initialQuestion!;
      await _ask();
    }
  }

  Future<void> _ask() async {
    if (_busy) return;

    final text = _question.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _busy = true;
      _messages.add({
        'role': 'user',
        'text': text,
      });
      _question.clear();
    });

    try {
      final result = await NubiService.call(
        'nubiAsk',
        {
          'question': text,
          if (widget.sourceId != null)
            'sourceId': widget.sourceId,
          'section': _sectionIndex,
          if (_sessionId != null)
            'sessionId': _sessionId,
        },
      );

      if (!mounted) return;

      setState(() {
        _sessionId = result['sessionId'].toString();
        _messages.add({
          'role': 'assistant',
          'text': result['answer'].toString(),
        });
      });
    } catch (error) {
      if (mounted) nubiMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _askPreset(String question) {
    _question.text = question;
    _ask();
  }

  Future<void> _startCheckpoint() async {
    if (_busy || widget.sourceId == null) return;

    setState(() => _busy = true);

    try {
      final result = await NubiService.call(
        'nubiCheckpoint',
        {
          'sourceId': widget.sourceId,
          'section': _sectionIndex,
        },
      );

      if (mounted) {
        setState(() {
          _checkpoint = result;
          _feedback = null;
        });
      }
    } catch (error) {
      if (mounted) nubiMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answerCheckpoint(int choice) async {
    if (_busy || widget.sourceId == null ||
        _feedback != null) {
      return;
    }

    setState(() => _busy = true);

    try {
      final result = await NubiService.call(
        'nubiCheckpointAnswer',
        {
          'sourceId': widget.sourceId,
          'section': _sectionIndex,
          'choice': choice,
        },
      );

      if (mounted) {
        setState(() => _feedback = result);
      }
    } catch (error) {
      if (mounted) nubiMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeSection(int index, int total) {
    if (index < 0 || index >= total) return;

    setState(() {
      _sectionIndex = index;
      _checkpoint = null;
      _feedback = null;
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = (_source?['sections'] as List?)
        ?.whereType<Map>()
        .toList() ?? [];

    final hasSource = widget.sourceId != null;

    final section = sections.isNotEmpty &&
        _sectionIndex < sections.length
        ? sections[_sectionIndex]
        : null;

    return nubiPage(
      hasSource
          ? (_source?['title'] ?? 'NUBi Tutor').toString()
          : 'NUBi Tutor',
      Column(
        children: [
          if (section != null)
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Section ${_sectionIndex + 1}/${sections.length}',
                      style: const TextStyle(
                        color: nubiBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      (section['title'] ?? '').toString(),
                      style: Theme.of(context)
                          .textTheme.titleMedium,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      (section['brief'] ?? '').toString(),
                      maxLines: 9,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 5,
                      children: [
                        TextButton(
                          onPressed: () => _askPreset(
                            'Explain this section simply.',
                          ),
                          child: const Text('Simpler'),
                        ),
                        TextButton(
                          onPressed: () => _askPreset(
                            'Explain this section in detail.',
                          ),
                          child: const Text('In Detail'),
                        ),
                        TextButton(
                          onPressed: () => _askPreset(
                            'Give a helpful example.',
                          ),
                          child: const Text('Example'),
                        ),
                        TextButton(
                          onPressed: () => _askPreset(
                            'Explain the clinical application.',
                          ),
                          child: const Text('Clinical'),
                        ),
                      ],
                    ),
                    FilledButton.tonal(
                      onPressed: _startCheckpoint,
                      child: const Text(
                        'Quick Knowledge Check',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_checkpoint != null)
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Text(
                      _checkpoint!['question'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (int i = 0;
                    i < (_checkpoint!['options'] as List)
                        .length;
                    i++)
                      ListTile(
                        title: Text(
                          (_checkpoint!['options'] as List)[i]
                              .toString(),
                        ),
                        onTap: _feedback == null
                            ? () => _answerCheckpoint(i)
                            : null,
                      ),
                    if (_feedback != null)
                      Text(
                        '${_feedback!['correct'] == true ? 'Correct!' : 'Incorrect.'} '
                            '${_feedback!['explanation'] ?? ''} '
                            'XP: ${_feedback!['earned'] ?? 0}',
                      ),
                  ],
                ),
              ),
            ),

          if (section != null)
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => _changeSection(
                    _sectionIndex - 1,
                    sections.length,
                  ),
                  child: const Text('Previous'),
                ),
                TextButton(
                  onPressed: () => _changeSection(
                    _sectionIndex + 1,
                    sections.length,
                  ),
                  child: const Text('Next Section'),
                ),
              ],
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final message in _messages)
                  Align(
                    alignment:
                    message['role'] == 'user'
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Card(
                      color: message['role'] == 'user'
                          ? nubiBlue.withValues(alpha: .12)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          message['text'] ?? '',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_busy)
            const LinearProgressIndicator(),

          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _question,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ask NUBi a question...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _busy ? null : _ask,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================
// BATCH 6: MCQ QUIZ RUNNER
// ===========================================

class NubiQuizRunScreen extends StatefulWidget {
  const NubiQuizRunScreen({
    super.key,
    required this.quizId,
  });

  final String quizId;

  @override
  State<NubiQuizRunScreen> createState() =>
      _NubiQuizRunScreenState();
}

class _NubiQuizRunScreenState
    extends State<NubiQuizRunScreen> {
  int _index = 0;
  int _correct = 0;
  bool _busy = false;
  Map<String, dynamic>? _feedback;
  final Set<int> _attempted = {};

  Future<void> _submit(int choice) async {
    if (_busy || _feedback != null) return;

    setState(() => _busy = true);

    try {
      final result =
      await NubiService.submitQuizAnswer(
        widget.quizId,
        _index,
        choice,
      );

      if (!mounted) return;

      setState(() {
        _feedback = result;
        if (_attempted.add(_index) &&
            result['correct'] == true &&
            result['firstAttempt'] == true) {
          _correct++;
        }
      });
    } catch (error) {
      if (mounted) nubiMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: NubiService.quizzes
          .doc(widget.quizId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return nubiPage(
            'MCQs',
            const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data!.data();

        if (data == null) {
          return nubiPage(
            'MCQs',
            nubiEmpty('Quiz not found.'),
          );
        }

        final questions =
            (data['questions'] as List?) ?? [];

        if (questions.isEmpty) {
          return nubiPage(
            'MCQs',
            nubiEmpty('No questions found.'),
          );
        }

        if (_index >= questions.length) {
          return nubiPage(
            'Quiz Results',
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_correct/${questions.length} correct',
                    style: Theme.of(context)
                        .textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Accuracy: ${(_correct * 100 / questions.length).round()}%',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    child: const Text('Back to My Deck'),
                  ),
                ],
              ),
            ),
          );
        }

        final question = Map<String, dynamic>.from(
          questions[_index] as Map,
        );

        final options =
            (question['options'] as List?) ?? [];

        return nubiPage(
          'MCQs',
          ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Question ${_index + 1}/${questions.length}',
                style: const TextStyle(
                  color: nubiBlue,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                question['question'].toString(),
                style: Theme.of(context)
                    .textTheme.titleLarge,
              ),

              const SizedBox(height: 18),

              for (int i = 0; i < options.length; i++)
                Card(
                  child: ListTile(
                    leading: Text(
                      String.fromCharCode(65 + i),
                    ),
                    title: Text(
                      options[i].toString(),
                    ),
                    onTap: _busy ||
                        _feedback != null
                        ? null
                        : () => _submit(i),
                  ),
                ),

              if (_busy)
                const LinearProgressIndicator(),

              if (_feedback != null) ...[
                const SizedBox(height: 15),

                Text(
                  _feedback!['correct'] == true
                      ? 'Correct!'
                      : 'Incorrect',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  (_feedback!['explanation'] ?? '')
                      .toString(),
                ),

                Text(
                  'XP earned: ${_feedback!['earned'] ?? 0}',
                ),

                const SizedBox(height: 16),

                FilledButton(
                  onPressed: () {
                    setState(() {
                      _index++;
                      _feedback = null;
                    });
                  },
                  child: Text(
                    _index + 1 == questions.length
                        ? 'View Results'
                        : 'Next Question',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ===========================================
// BATCH 7: FLASHCARDS
// ===========================================

class NubiFlashcardsRunScreen
    extends StatefulWidget {
  const NubiFlashcardsRunScreen({
    super.key,
    required this.deckId,
  });

  final String deckId;

  @override
  State<NubiFlashcardsRunScreen> createState() =>
      _NubiFlashcardsRunScreenState();
}

class _NubiFlashcardsRunScreenState
    extends State<NubiFlashcardsRunScreen> {
  int _index = 0;
  bool _flipped = false;
  bool _busy = false;

  Future<void> _rate(String rating) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final result =
      await NubiService.reviewFlashcard(
        widget.deckId,
        _index,
        rating,
      );

      if (!mounted) return;

      nubiMessage(
        context,
        '+${result['earned'] ?? 0} NUBi XP',
      );

      setState(() {
        _index++;
        _flipped = false;
      });
    } catch (error) {
      if (mounted) nubiMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: NubiService.decks
          .doc(widget.deckId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return nubiPage(
            'Flashcards',
            const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final cards =
            (snapshot.data!.data()?['cards'] as List?)
                ?? [];

        if (_index >= cards.length) {
          return nubiPage(
            'Flashcards',
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 55,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Review session complete!',
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    child: const Text('Finish'),
                  ),
                ],
              ),
            ),
          );
        }

        final card = Map<String, dynamic>.from(
          cards[_index] as Map,
        );

        return nubiPage(
          'Flashcards',
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Card ${_index + 1}/${cards.length}',
                ),
              ),

              Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                        () => _flipped = !_flipped,
                  ),
                  child: AnimatedSwitcher(
                    duration: MediaQuery.of(context)
                        .disableAnimations
                        ? Duration.zero
                        : const Duration(
                      milliseconds: 260,
                    ),
                    child: Container(
                      key: ValueKey(
                        '${_index}_$_flipped',
                      ),
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(26),
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _flipped
                            ? const Color(0xFF4338CA)
                            : const Color(0xFF0E7490),
                        borderRadius:
                        BorderRadius.circular(26),
                      ),
                      child: Text(
                        _flipped
                            ? card['back'].toString()
                            : card['front'].toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (!_flipped)
                const Text(
                  'Tap the card to reveal the answer',
                ),

              if (_flipped)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 7,
                    children: [
                      for (final rating in [
                        'again', 'hard', 'good', 'easy'
                      ])
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _rate(rating),
                          child: Text(
                            rating.toUpperCase(),
                          ),
                        ),
                    ],
                  ),
                ),

              if (_busy)
                const LinearProgressIndicator(),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================
// BATCH 9: MY PROGRESS
// ===========================================

class NubiProgressScreen extends StatelessWidget {
  const NubiProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return nubiPage(
      'My Progress',
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: NubiService.progress.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.data() ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _progressTile(
                'Lifetime NUBi XP',
                '${data['lifetime'] ?? 0}',
                Icons.emoji_events_rounded,
              ),
              _progressTile(
                'Today',
                '${data['daily'] ?? 0}',
                Icons.today_rounded,
              ),
              _progressTile(
                'This Week',
                '${data['weekly'] ?? 0}',
                Icons.calendar_view_week,
              ),
              _progressTile(
                'This Month',
                '${data['monthly'] ?? 0}',
                Icons.calendar_month,
              ),
              const SizedBox(height: 20),
              const Text(
                'XP is awarded by secure backend '
                    'events, not directly by the app.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _progressTile(
      String title,
      String value,
      IconData icon,
      ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: nubiBlue),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// ===========================================
// BATCH 10: LEADERBOARDS
// ===========================================

class NubiLeaderboardScreen
    extends StatefulWidget {
  const NubiLeaderboardScreen({super.key});

  @override
  State<NubiLeaderboardScreen> createState() =>
      _NubiLeaderboardScreenState();
}

class _NubiLeaderboardScreenState
    extends State<NubiLeaderboardScreen> {
  String _scope = 'University';
  String _period = 'All Time';

  String get _periodKey {
    final now = DateTime.now().toUtc();
    final date = now.toIso8601String().substring(0, 10);

    if (_period == 'Today') {
      return 'day_$date';
    }

    if (_period == 'This Month') {
      return 'month_${date.substring(0, 7)}';
    }

    if (_period == 'This Week') {
      final monday = now.subtract(
        Duration(days: now.weekday - 1),
      );
      final key = monday
          .toIso8601String()
          .substring(0, 10);
      return 'week_$key';
    }

    return 'all';
  }

  @override
  Widget build(BuildContext context) {
    return nubiPage(
      '🏆 NUBi Leaderboards',
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'My Faculty',
                      label: Text('My Faculty'),
                    ),
                    ButtonSegment(
                      value: 'University',
                      label: Text('University'),
                    ),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (values) {
                    setState(() {
                      _scope = values.first;
                    });
                  },
                ),

                const SizedBox(height: 10),

                DropdownButton<String>(
                  value: _period,
                  isExpanded: true,
                  items: [
                    'Today',
                    'This Week',
                    'This Month',
                    'All Time',
                  ].map((period) => DropdownMenuItem(
                    value: period,
                    child: Text(period),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _period = value);
                    }
                  },
                ),

                TextButton(
                  onPressed: () async {
                    try {
                      await NubiService.call(
                        'nubiSetRankingOptIn',
                        {'enabled': true},
                      );

                      if (context.mounted) {
                        nubiMessage(
                          context,
                          'Leaderboard visibility enabled. '
                              'Faculty verification is required.',
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        nubiMessage(context, error);
                      }
                    }
                  },
                  child: const Text(
                    'Opt in to public rankings',
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(

              stream: (_scope == 'My Faculty'
                  ? NubiService.db
                  .collection('nubiRankings')
                  .doc(_periodKey)
                  .collection('players')
                  .where(
                'faculty',
                isEqualTo: _myFaculty,
              )
                  : NubiService.db
                  .collection('nubiRankings')
                  .doc(_periodKey)
                  .collection('players'))
                  .orderBy('xp', descending: true)
                  // Only the top ten students are ranked.
                  .limit(10)
                  .snapshots(),

              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return nubiEmpty(
                    'Could not load rankings. '
                        'Check Firebase permissions.',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final all = snapshot.data!.docs;

                // For production, replace the client
                // filter with an indexed faculty query.
                final docs = (_scope == 'University'
                    ? all
                    : all.where(
                      (doc) =>
                  doc.data()['faculty'] ==
                      _myFaculty,
                ))
                    .take(10)
                    .toList();

                if (docs.isEmpty) {
                  return nubiEmpty(
                    'No verified rankings yet.',
                  );
                }

                final String me =
                    FirebaseAuth.instance.currentUser?.uid ?? '';

                // Top three stand on the podium; everyone
                // else gets a ranked card with their title.
                final podium = docs.take(3).toList();
                final rest = docs.skip(3).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  children: [
                    _RankPodium(
                      students: podium
                          .map((doc) => doc.data())
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    for (int i = 0; i < rest.length; i++)
                      _RankCard(
                        rank: i + 4,
                        student: rest[i].data(),
                        isMe: rest[i].id == me,
                      ),
                    if (podium.any((doc) => doc.id == me))
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'You are on the podium! Keep it up 🎉',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // This is populated from the verified faculty
  // membership in the final ranking integration.

  String _myFaculty = '';

  @override
  void initState() {
    super.initState();
    _loadFaculty();
  }

  Future<void> _loadFaculty() async {
    try {
      final doc = await NubiService.db
          .collection('nubiMembership')
          .doc(NubiService.uid)
          .get();

      if (!mounted) return;

      final data = doc.data();

      if (data?['verified'] == true) {
        setState(() {
          _myFaculty =
              (data?['faculty'] ?? '').toString();
        });
      }
    } catch (error) {
      debugPrint('Faculty verification: $error');
    }
  }

}

// ===========================================
// RANK TITLES AND MEDALS
//
// Each of the top ten earns a title and a
// medal, so everyone on the board feels proud.
// ===========================================

class _RankTier {
  const _RankTier(this.medal, this.title, this.colors);

  final String medal;
  final String title;
  final List<Color> colors;
}

_RankTier _rankTierFor(int rank) {
  if (rank == 1) {
    return const _RankTier('🥇', 'Grand Champion', [
      Color(0xFFFFD54F),
      Color(0xFFF59E0B),
    ]);
  }
  if (rank == 2) {
    return const _RankTier('🥈', 'Silver Genius', [
      Color(0xFFE2E8F0),
      Color(0xFF94A3B8),
    ]);
  }
  if (rank == 3) {
    return const _RankTier('🥉', 'Bronze Brain', [
      Color(0xFFFDBA74),
      Color(0xFFB45309),
    ]);
  }
  if (rank <= 5) {
    return const _RankTier('🏅', 'Elite Scholar', [
      Color(0xFFA78BFA),
      Color(0xFF6D28D9),
    ]);
  }
  if (rank <= 10) {
    return const _RankTier('🌟', 'Rising Star', [
      Color(0xFF38BDF8),
      Color(0xFF2563EB),
    ]);
  }
  return const _RankTier('🔥', 'Challenger', [
    Color(0xFFFB923C),
    Color(0xFFEF4444),
  ]);
}

String _studentName(Map<String, dynamic> student) =>
    (student['displayName'] ?? 'Student').toString();

// ===========================================
// PODIUM FOR THE TOP THREE
// ===========================================

class _RankPodium extends StatelessWidget {
  const _RankPodium({required this.students});

  final List<Map<String, dynamic>> students;

  Widget _place(BuildContext context, int rank, double height) {
    if (students.length < rank) {
      return const Expanded(child: SizedBox.shrink());
    }

    final Map<String, dynamic> student = students[rank - 1];
    final _RankTier tier = _rankTierFor(rank);

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (rank == 1) const Text('👑', style: TextStyle(fontSize: 26)),
          Text(tier.medal, style: TextStyle(fontSize: rank == 1 ? 40 : 32)),
          const SizedBox(height: 4),
          Text(
            _studentName(student),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${student['xp'] ?? 0} XP',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: tier.colors,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: tier.colors.last.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    tier.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Second, first, third, like a real podium.
    return SizedBox(
      height: 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _place(context, 2, 96),
          _place(context, 1, 124),
          _place(context, 3, 78),
        ],
      ),
    );
  }
}

// ===========================================
// RANKED CARD FROM 4TH PLACE DOWN
// ===========================================

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.rank,
    required this.student,
    required this.isMe,
  });

  final int rank;
  final Map<String, dynamic> student;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final _RankTier tier = _rankTierFor(rank);
    final String faculty = (student['faculty'] ?? '').toString();
    final String name = _studentName(student);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? tier.colors.last
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: isMe ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tier.colors,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(tier.medal, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '$name (You)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tier.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          // Lighter shade on dark backgrounds.
                          color: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? tier.colors.first
                              : tier.colors.last,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (faculty.isNotEmpty)
                      Flexible(
                        child: Text(
                          ' · $faculty',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${student['xp'] ?? 0} XP',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
