
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:path_provider/path_provider.dart';

import '../egyptian_arabic/ea_models.dart';
import '../egyptian_arabic/ea_service.dart';

//===================================================
// NUBIFY EGYPTIAN ARABIC — APP STYLING
//===================================================

class _EAStyle {
  static const navy = Color(0xFF101722);
  static const panel = Color(0xFF192332);
  static const slate = Color(0xFF252E3B);
  static const sky = Color(0xFF29B6F6);
  static const teal = Color(0xFF52B6B0);
  static const ivory = Color(0xFFF5F6F4);
  static const muted = Color(0xFF9DAAB9);
  static const amber = Color(0xFFE9B86D);
  static const coral = Color(0xFFD57B7B);
}

//===================================================
// MAIN DASHBOARD AND SHARED DECKS
//===================================================

class EgyptianArabicScreen extends StatefulWidget {
  const EgyptianArabicScreen({super.key});

  @override
  State<EgyptianArabicScreen> createState() =>
      _EgyptianArabicScreenState();
}

class _EgyptianArabicScreenState
    extends State<EgyptianArabicScreen> {
  final EaLearningService _service = EaLearningService();

  late final Stream<List<EaDeck>> _decksStream;
  late final Stream<List<EaCard>> _cardsStream;

  @override
  void initState() {
    super.initState();

    if (FirebaseAuth.instance.currentUser != null) {
      _decksStream = _service.watchDecks();
      _cardsStream = _service.watchCards();
    }
  }

  Future<void> _addDeck() async {
    final controller = TextEditingController();

    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _EAStyle.panel,
          title: const Text(
            'Create Shared Deck',
            style: TextStyle(color: _EAStyle.ivory),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            style: const TextStyle(color: _EAStyle.ivory),
            decoration: _eaInput(
              'Deck name',
              Icons.layers_outlined,
            ),
            onSubmitted: (value) =>
                Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                controller.text,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      );

      if (name == null || name.trim().isEmpty) {
        return;
      }

      await _service.createDeck(name);

      if (mounted) {
        _eaMessage(context, 'Shared deck created.');
      }
    } catch (error) {
      if (mounted) {
        _eaMessage(context, error.toString());
      }
    } finally {
      controller.dispose();
    }
  }

  void _openReview({
    String? deckId,
    String title = 'Daily Review',
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _EAReviewScreen(
          service: _service,
          deckId: deckId,
          title: title,
        ),
      ),
    );
  }

  void _openCreateCard() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _EACreateCardScreen(
          service: _service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(
        backgroundColor: _EAStyle.navy,
        body: Center(
          child: Text(
            'Sign in to learn Egyptian Arabic.',
            style: TextStyle(color: _EAStyle.ivory),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _EAStyle.navy,
      floatingActionButton:
      FloatingActionButton.extended(
        backgroundColor: _EAStyle.sky,
        foregroundColor: _EAStyle.navy,
        onPressed: _openCreateCard,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Flashcard'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<EaDeck>>(
          stream: _decksStream,
          builder: (context, deckSnapshot) {
            if (deckSnapshot.hasError) {
              return _EAError(
                deckSnapshot.error.toString(),
              );
            }

            return StreamBuilder<List<EaCard>>(
              stream: _cardsStream,
              builder: (context, cardSnapshot) {
                if (cardSnapshot.hasError) {
                  return _EAError(
                    cardSnapshot.error.toString(),
                  );
                }

                if (!deckSnapshot.hasData ||
                    !cardSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _EAStyle.sky,
                    ),
                  );
                }

                final decks = deckSnapshot.data!;

                final cards = cardSnapshot.data!
                    .where((card) => !card.reversed)
                    .toList();

                final available = cards
                    .where((card) => !card.suspended)
                    .toList();

                final due = available
                    .where((card) => card.isDue)
                    .length;

                final fresh = available
                    .where((card) => card.isNew)
                    .length;

                final learning = available.where((card) {
                  if (card.isNew) return false;

                  return fsrs.Card.fromMap(
                    card.schedule,
                  ).state !=
                      fsrs.State.review;
                }).length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    18,
                    18,
                    120,
                  ),
                  children: [
                    // Welcome header

                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF17466B),
                                Color(0xFF286A69),
                                Color(0xFF6C4D72),
                              ],
                            ),
                            borderRadius:
                            BorderRadius.circular(19),
                          ),
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                                  colors: [
                                    _EAStyle.sky,
                                    _EAStyle.teal,
                                    _EAStyle.amber,
                                    _EAStyle.coral,
                                  ],
                                ).createShader(bounds),
                            child: const Icon(
                              Icons.public_rounded,
                              color: Colors.white,
                              size: 39,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AHLAN!  •  WELCOME',
                                style: TextStyle(
                                  color: _EAStyle.teal,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Speak Egyptian with confidence',
                                style: TextStyle(
                                  color: _EAStyle.ivory,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                  height: 1.15,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Learn a little Masri every day.',
                                style: TextStyle(
                                  color: _EAStyle.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Create deck',
                          onPressed: _addDeck,
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            color: _EAStyle.ivory,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Daily review overview

                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF244B67),
                            _EAStyle.panel,
                          ],
                        ),
                        borderRadius:
                        BorderRadius.circular(23),
                        border: Border.all(
                          color: _EAStyle.sky.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'READY FOR TODAY?',
                            style: TextStyle(
                              color: _EAStyle.teal,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$due',
                            style: const TextStyle(
                              color: _EAStyle.ivory,
                              fontSize: 45,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Flashcards due for review',
                            style: TextStyle(
                              color: _EAStyle.ivory,
                            ),
                          ),
                          const SizedBox(height: 19),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: available.isEmpty
                                  ? null
                                  : () => _openReview(),
                              style: FilledButton.styleFrom(
                                backgroundColor: _EAStyle.sky,
                                foregroundColor: _EAStyle.navy,
                              ),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                              ),
                              label: Text(
                                available.isEmpty
                                    ? 'No Flashcards Yet'
                                    : due > 0
                                    ? 'Continue Learning'
                                    : 'Practice Anytime',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _EAMetric(
                            'New',
                            fresh,
                            _EAStyle.sky,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _EAMetric(
                            'Learning',
                            learning,
                            _EAStyle.amber,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _EAMetric(
                            'Total',
                            cards.length,
                            _EAStyle.teal,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 27),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Community decks',
                            style: TextStyle(
                              color: _EAStyle.ivory,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addDeck,
                          icon: const Icon(Icons.add),
                          label: const Text('New deck'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (decks.isEmpty)
                      _EAPanel(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.layers_outlined,
                              color: _EAStyle.sky,
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No shared decks yet',
                              style: TextStyle(
                                color: _EAStyle.ivory,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _addDeck,
                              child: const Text(
                                'Create First Deck',
                              ),
                            ),
                          ],
                        ),
                      ),

                    for (final deck in decks)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 11,
                        ),
                        child: _EAPanel(
                          child: InkWell(
                            onTap: () => _openReview(
                              deckId: deck.id,
                              title: deck.name,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.menu_book_rounded,
                                  color: _EAStyle.sky,
                                  size: 30,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        deck.name,
                                        style: const TextStyle(
                                          color: _EAStyle.ivory,
                                          fontWeight:
                                          FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${cards.where((c) => c.deckId == deck.id).length} cards  •  '
                                            '${cards.where((c) => c.deckId == deck.id && c.isDue).length} due',
                                        style: const TextStyle(
                                          color: _EAStyle.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: _EAStyle.sky,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

//===================================================
// FLASHCARD REVIEW — COMPACT, NO FLIPPING
//===================================================

class _EAReviewScreen extends StatefulWidget {
  const _EAReviewScreen({
    required this.service,
    this.deckId,
    this.title = 'Daily Review',
  });

  final EaLearningService service;
  final String? deckId;
  final String title;

  @override
  State<_EAReviewScreen> createState() =>
      _EAReviewScreenState();
}

class _EAReviewScreenState
    extends State<_EAReviewScreen> {
  final AudioPlayer _player = AudioPlayer();

  final Set<String> _reviewedThisRound =
  <String>{};

  late final Stream<List<EaCard>> _cardsStream;

  String? _revealedCardId;
  EaCard? _lastCard;

  int _completed = 0;
  int _roundCardCount = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _cardsStream = widget.service.watchCards();
  }

  Future<void> _play(String url) async {
    if (url.trim().isEmpty) return;

    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (error) {
      if (mounted) {
        _eaMessage(context, error.toString());
      }
    }
  }

  Future<void> _reveal(EaCard card) async {
    if (_submitting ||
        _revealedCardId == card.id) {
      return;
    }

    setState(() {
      _revealedCardId = card.id;
    });

    HapticFeedback.selectionClick();

    await Future<void>.delayed(
      const Duration(milliseconds: 150),
    );

    if (mounted &&
        !_submitting &&
        _revealedCardId == card.id) {
      await _play(card.audioUrl);
    }
  }

  //===================================================
  // FSRS GRADING AND UNDO
  //===================================================

  Future<void> _grade(
      EaCard card,
      fsrs.Rating rating,
      ) async {
    if (_submitting) return;

    setState(() {
      _submitting = true;
    });

    try {
      await _player.stop();

      await widget.service.grade(
        card,
        rating,
      );

      if (!mounted) return;

      HapticFeedback.selectionClick();

      setState(() {
        _reviewedThisRound.add(card.id);
        _lastCard = card;
        _completed++;
        _revealedCardId = null;

        // Restart automatically after every card
        // has appeared once during this round.
        if (_roundCardCount > 0 &&
            _reviewedThisRound.length >=
                _roundCardCount) {
          _reviewedThisRound.clear();
        }
      });
    } catch (error) {
      if (mounted) {
        _eaMessage(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _undo() async {
    final card = _lastCard;

    if (card == null || _submitting) {
      return;
    }

    try {
      await _player.stop();
      await widget.service.undoLatest(card.id);

      if (!mounted) return;

      setState(() {
        _reviewedThisRound.remove(card.id);
        _completed = math.max(
          0,
          _completed - 1,
        );
        _lastCard = null;
        _revealedCardId = null;
      });
    } catch (error) {
      if (mounted) {
        _eaMessage(context, error.toString());
      }
    }
  }

  Future<void> _action(
      String action,
      EaCard card,
      ) async {
    if (action == 'undo') {
      await _undo();
      return;
    }

    try {
      if (action == 'suspend') {
        await widget.service.setSuspended(
          card,
          true,
        );
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(
              'Delete shared flashcard?',
            ),
            content: const Text(
              'This removes the flashcard for all students.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  false,
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  true,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await widget.service.deleteNote(card);
        }
      }
    } catch (error) {
      if (mounted) {
        _eaMessage(context, error.toString());
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  //===================================================
  // REVIEW UI — BUTTONS IMMEDIATELY BELOW CARD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _EAStyle.navy,
      appBar: AppBar(
        backgroundColor: _EAStyle.navy,
        foregroundColor: _EAStyle.ivory,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Undo review',
            onPressed:
            _lastCard == null || _submitting
                ? null
                : _undo,
            icon: const Icon(
              Icons.undo_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: StreamBuilder<List<EaCard>>(
          stream: _cardsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _EAError(
                snapshot.error.toString(),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _EAStyle.sky,
                ),
              );
            }

            final availableCards = snapshot.data!
                .where(
                  (card) =>
              !card.reversed &&
                  !card.suspended &&
                  (widget.deckId == null ||
                      card.deckId ==
                          widget.deckId),
            )
                .toList();

            _roundCardCount = availableCards.length;

            if (availableCards.isEmpty) {
              return const Center(
                child: Text(
                  'No flashcards available in this deck.',
                  style: TextStyle(
                    color: _EAStyle.ivory,
                  ),
                ),
              );
            }

            final unstudied = availableCards
                .where(
                  (card) =>
              !_reviewedThisRound.contains(
                card.id,
              ),
            )
                .toList();

            if (unstudied.isEmpty) {
              return Center(
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _reviewedThisRound.clear();
                      _revealedCardId = null;
                    });
                  },
                  icon: const Icon(
                    Icons.replay_rounded,
                  ),
                  label: const Text('Study Again'),
                ),
              );
            }

            // Due cards first, followed by practice cards.
            unstudied.sort((a, b) {
              if (a.isDue != b.isDue) {
                return a.isDue ? -1 : 1;
              }

              if (a.isNew != b.isNew) {
                return a.isNew ? 1 : -1;
              }

              return a.dueAt.compareTo(
                b.dueAt,
              );
            });

            final card = unstudied.first;
            final revealed =
                _revealedCardId == card.id;

            final intervals = revealed
                ? widget.service.preview(card)
                : null;

            final dueInQueue = unstudied
                .where((c) => c.isDue)
                .length;

            // ListView keeps controls scrollable above
            // system navigation, even on small displays.
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.viewPaddingOf(context).bottom +
                    110,
              ),
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
              children: [
                Row(
                  children: [
                    Text(
                      '$_completed studied',
                      style: const TextStyle(
                        color: _EAStyle.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dueInQueue > 0
                          ? '$dueInQueue due'
                          : 'Practice • ${unstudied.length}',
                      style: const TextStyle(
                        color: _EAStyle.sky,
                      ),
                    ),
                    PopupMenuButton<String>(
                      color: _EAStyle.slate,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: _EAStyle.ivory,
                      ),
                      onSelected: (action) =>
                          _action(action, card),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'suspend',
                          child: Text('Suspend card'),
                        ),
                        if (card.createdBy ==
                            FirebaseAuth.instance
                                .currentUser?.uid)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete note'),
                          ),
                        if (_lastCard != null)
                          const PopupMenuItem(
                            value: 'undo',
                            child: Text('Undo review'),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),


                //===================================================
                // FLASHCARD — BALANCED SIZE, NO FLIPPING
                //===================================================

                GestureDetector(
                  onTap: revealed ? null : () => _reveal(card),
                  child: _EAPanel(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 220,
                        maxHeight: 430,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 22,
                            horizontal: 4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'FRONT — ENGLISH',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _EAStyle.sky,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),

                              const SizedBox(height: 18),

                              Text(
                                card.front,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _EAStyle.ivory,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),

                              if (revealed) ...[
                                const SizedBox(height: 22),

                                const Divider(
                                  color: Color(0xFF435365),
                                  thickness: 1,
                                ),

                                const SizedBox(height: 18),

                                const Text(
                                  'BACK — LATIN PRONUNCIATION',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _EAStyle.teal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),

                                const SizedBox(height: 18),

                                Text(
                                  card.transliteration,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _EAStyle.ivory,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    height: 1.25,
                                  ),
                                ),

                                if (card.audioUrl.isNotEmpty) ...[
                                  const SizedBox(height: 16),

                                  OutlinedButton.icon(
                                    onPressed: () => _play(
                                      card.audioUrl,
                                    ),
                                    icon: const Icon(
                                      Icons.replay_rounded,
                                      size: 19,
                                    ),
                                    label: const Text(
                                      'Tap to Replay',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _EAStyle.sky,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 19,
                                        vertical: 10,
                                      ),
                                      side: const BorderSide(
                                        color: _EAStyle.sky,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(24),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

               //distance between card and show answer/again,hard,good,easy
                const SizedBox(height: 270),
                if (!revealed)
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () =>
                          _reveal(card),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                        _EAStyle.sky,
                        foregroundColor:
                        _EAStyle.navy,
                      ),
                      child: const Text(
                        'Show Answer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      for (final rating
                      in fsrs.Rating.values)
                        Expanded(
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 2,
                            ),
                            child: _EAGradeButton(
                              label: rating.name[0]
                                  .toUpperCase() +
                                  rating.name.substring(1),
                              interval: _eaInterval(
                                intervals![rating]!,
                              ),
                              color: switch (rating) {
                                fsrs.Rating.again =>
                                _EAStyle.coral,
                                fsrs.Rating.hard =>
                                _EAStyle.amber,
                                fsrs.Rating.good =>
                                _EAStyle.teal,
                                fsrs.Rating.easy =>
                                _EAStyle.sky,
                              },
                              onPressed: _submitting
                                  ? null
                                  : () => _grade(
                                card,
                                rating,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EAGradeButton extends StatelessWidget {
  const _EAGradeButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final String interval;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(
          alpha: 0.16,
        ),
        foregroundColor: color,
        disabledBackgroundColor: _EAStyle.panel,
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: color.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            interval,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _eaInterval(DateTime due) {
  final duration = due.difference(
    DateTime.now().toUtc(),
  );

  if (duration.inSeconds < 60) return '<1m';
  if (duration.inMinutes < 60) {
    return '${duration.inMinutes}m';
  }
  if (duration.inHours < 36) {
    return '${duration.inHours}h';
  }
  if (duration.inDays < 30) {
    return '${duration.inDays}d';
  }
  if (duration.inDays < 365) {
    return '${(duration.inDays / 30).round()}mo';
  }

  return '${(duration.inDays / 365).toStringAsFixed(1)}y';
}

//===================================================
// CREATE FLASHCARD — ENGLISH, LATIN, AUDIO
//===================================================

class _EACreateCardScreen extends StatefulWidget {
  const _EACreateCardScreen({
    required this.service,
  });

  final EaLearningService service;

  @override
  State<_EACreateCardScreen> createState() =>
      _EACreateCardScreenState();
}

class _EACreateCardScreenState
    extends State<_EACreateCardScreen> {
  final TextEditingController _english =
  TextEditingController();

  final TextEditingController _latin =
  TextEditingController();

  final AudioPlayer _player = AudioPlayer();

  late final Stream<List<EaDeck>> _decksStream;

  StreamSubscription<PlayerState>?
  _stateSubscription;

  StreamSubscription<Duration>?
  _positionSubscription;

  StreamSubscription<Duration>?
  _durationSubscription;

  StreamSubscription<void>?
  _completeSubscription;

  String? _deckId;
  String? _audioPath;

  bool _saving = false;
  bool _selectingAudio = false;
  bool _playing = false;
  bool _previewed = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _decksStream = widget.service.watchDecks();

    _stateSubscription =
        _player.onPlayerStateChanged.listen((state) {
          if (mounted) {
            setState(() {
              _playing = state == PlayerState.playing;
            });
          }
        });

    _positionSubscription =
        _player.onPositionChanged.listen((value) {
          if (mounted) {
            setState(() {
              _position = value;
            });
          }
        });

    _durationSubscription =
        _player.onDurationChanged.listen((value) {
          if (mounted) {
            setState(() {
              _duration = value;
            });
          }
        });

    _completeSubscription =
        _player.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _position = Duration.zero;
              _playing = false;
            });
          }
        });
  }

  //===================================================
  // AUDIO SELECTION AND PLAYBACK PREVIEW
  //===================================================

  Future<void> _pickAudio() async {
    if (_saving || _selectingAudio) return;

    setState(() {
      _selectingAudio = true;
    });

    try {
      final PlatformFile? selected =
      await FilePicker.pickFile(
        type: FileType.audio,
      );

      if (selected == null) return;

      final extension =
      (selected.extension ??
          selected.name.split('.').last)
          .toLowerCase();

      const allowed = <String>{
        'mp3',
        'm4a',
        'aac',
        'wav',
        'ogg',
        'flac',
      };

      if (!allowed.contains(extension)) {
        throw StateError(
          'Choose MP3, M4A, AAC, WAV, OGG or FLAC.',
        );
      }

      const maxBytes = 12 * 1024 * 1024;

      final size = selected.lengthSync() ??
          await selected.length();

      if (size != null && size > maxBytes) {
        throw StateError(
          'Audio must be 12 MB or smaller.',
        );
      }

      String? path = selected.path;

      if (path == null ||
          !await File(path).exists()) {
        final bytes = await selected.readAsBytes();

        if (bytes.length > maxBytes) {
          throw StateError(
            'Audio must be 12 MB or smaller.',
          );
        }

        final temp =
        await getTemporaryDirectory();

        path =
        '${temp.path}/nubify_egyptian_'
            '${DateTime.now().microsecondsSinceEpoch}'
            '.$extension';

        await File(path).writeAsBytes(
          bytes,
          flush: true,
        );
      }

      await _player.stop();

      if (!mounted) return;

      setState(() {
        _audioPath = path;
        _previewed = false;
        _playing = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
    } catch (error) {
      if (mounted) {
        _eaMessage(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectingAudio = false;
        });
      }
    }
  }

  Future<void> _previewAudio() async {
    final path = _audioPath;
    if (path == null) return;

    try {
      if (_playing) {
        await _player.pause();
      } else if (_previewed &&
          _position > Duration.zero &&
          _position < _duration) {
        await _player.resume();
      } else {
        await _player.stop();

        await _player.play(
          DeviceFileSource(path),
        );

        if (mounted) {
          setState(() {
            _previewed = true;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        _eaMessage(context, error.toString());
      }
    }
  }

  Future<void> _removeAudio() async {
    await _player.stop();

    if (!mounted) return;

    setState(() {
      _audioPath = null;
      _previewed = false;
      _playing = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
  }

  //===================================================
  // SAVE SHARED FLASHCARD
  //===================================================

  Future<void> _save() async {
    if (_saving || _selectingAudio) return;

    if (_deckId == null) {
      _eaMessage(
        context,
        'Select a deck first.',
      );
      return;
    }

    if (_english.text.trim().isEmpty) {
      _eaMessage(
        context,
        'Enter the English word or phrase.',
      );
      return;
    }

    if (_latin.text.trim().isEmpty) {
      _eaMessage(
        context,
        'Enter the Latin pronunciation.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _player.stop();

      String audioUrl = '';

      if (_audioPath != null) {
        audioUrl =
        await widget.service.uploadAudio(
          _audioPath!,
        );
      }

      await widget.service.addNote(
        deckId: _deckId!,
        front: _english.text.trim(),
        arabic: '',
        transliteration: _latin.text.trim(),
        audioUrl: audioUrl,
        addReverse: false,
      );

      if (!mounted) return;

      final messenger =
      ScaffoldMessenger.of(context);

      Navigator.pop(context);

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Flashcard shared successfully!',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _eaMessage(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _english.dispose();
    _latin.dispose();

    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completeSubscription?.cancel();

    _player.dispose();

    super.dispose();
  }

  //===================================================
  // CREATE FLASHCARD USER INTERFACE
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _EAStyle.navy,
      appBar: AppBar(
        backgroundColor: _EAStyle.navy,
        foregroundColor: _EAStyle.ivory,
        title: const Text('Create Flashcard'),
        actions: [
          IconButton(
            tooltip: 'Save flashcard',
            onPressed:
            _saving || _selectingAudio
                ? null
                : _save,
            icon: const Icon(
              Icons.check_rounded,
              color: _EAStyle.sky,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: StreamBuilder<List<EaDeck>>(
          stream: _decksStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _EAError(
                snapshot.error.toString(),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _EAStyle.sky,
                ),
              );
            }

            final decks = snapshot.data!;

            if (decks.isNotEmpty &&
                !decks.any(
                      (deck) => deck.id == _deckId,
                )) {
              _deckId = decks.first.id;
            }

            // Save belongs to the scrollable form,
            // not to a bottom navigation bar.
            return ListView(
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                18,
                MediaQuery.viewPaddingOf(context).bottom +
                    110,
              ),
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
              children: [
                _EAPanel(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DECK',
                        style: TextStyle(
                          color: _EAStyle.sky,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_deckId),
                        initialValue: decks.any(
                              (deck) =>
                          deck.id == _deckId,
                        )
                            ? _deckId
                            : null,
                        isExpanded: true,
                        dropdownColor:
                        _EAStyle.slate,
                        style: const TextStyle(
                          color: _EAStyle.ivory,
                        ),
                        decoration: _eaInput(
                          'Choose deck',
                          Icons.layers_outlined,
                        ),
                        items: decks.map((deck) {
                          return DropdownMenuItem<String>(
                            value: deck.id,
                            child: Text(deck.name),
                          );
                        }).toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                          setState(() {
                            _deckId = value;
                          });
                        },
                      ),
                      if (decks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(
                            top: 10,
                          ),
                          child: Text(
                            'Create a deck from the dashboard first.',
                            style: TextStyle(
                              color: _EAStyle.amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _EAPanel(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FRONT — ENGLISH',
                        style: TextStyle(
                          color: _EAStyle.sky,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _english,
                        maxLength: 200,
                        style: const TextStyle(
                          color: _EAStyle.ivory,
                        ),
                        decoration: _eaInput(
                          'English word or phrase',
                          Icons.translate_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'BACK — LATIN PRONUNCIATION',
                        style: TextStyle(
                          color: _EAStyle.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _latin,
                        maxLength: 200,
                        style: const TextStyle(
                          color: _EAStyle.ivory,
                          fontSize: 20,
                        ),
                        decoration: _eaInput(
                          'e.g. shukran',
                          Icons.record_voice_over_outlined,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _EAPanel(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRONUNCIATION AUDIO',
                        style: TextStyle(
                          color: _EAStyle.sky,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Choose audio from your phone and listen before saving.',
                        style: TextStyle(
                          color: _EAStyle.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                          _saving || _selectingAudio
                              ? null
                              : _pickAudio,
                          icon: const Icon(
                            Icons.audio_file_outlined,
                          ),
                          label: Text(
                            _selectingAudio
                                ? 'Selecting Audio…'
                                : _audioPath == null
                                ? 'Add Audio from Phone'
                                : 'Replace Audio',
                          ),
                        ),
                      ),

                      if (_audioPath != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.audiotrack_rounded,
                              color: _EAStyle.teal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _audioPath!
                                    .split(
                                  Platform.pathSeparator,
                                )
                                    .last,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _EAStyle.ivory,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove audio',
                              onPressed:
                              _saving
                                  ? null
                                  : _removeAudio,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _EAStyle.coral,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 9),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                            _saving
                                ? null
                                : _previewAudio,
                            icon: Icon(
                              _playing
                                  ? Icons.pause_circle_rounded
                                  : Icons.play_circle_rounded,
                            ),
                            label: Text(
                              _playing
                                  ? 'Pause Preview'
                                  : _previewed
                                  ? 'Replay / Resume Preview'
                                  : 'Play Preview Before Saving',
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        LinearProgressIndicator(
                          minHeight: 5,
                          value:
                          _duration.inMilliseconds <= 0
                              ? 0
                              : (_position.inMilliseconds /
                              _duration
                                  .inMilliseconds)
                              .clamp(0.0, 1.0),
                          backgroundColor:
                          _EAStyle.slate,
                          color: _EAStyle.teal,
                        ),

                        const SizedBox(height: 5),

                        Text(
                          '${_eaAudioTime(_position)} / ${_eaAudioTime(_duration)}',
                          style: const TextStyle(
                            color: _EAStyle.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                    _saving || _selectingAudio
                        ? null
                        : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                      _EAStyle.sky,
                      foregroundColor:
                      _EAStyle.navy,
                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 17,
                      ),
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                    ),
                    label: Text(
                      _saving
                          ? 'Saving…'
                          : 'Save Flashcard',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

//===================================================
// REUSABLE WIDGETS AND HELPERS
//===================================================

String _eaAudioTime(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds =
  duration.inSeconds.remainder(60);

  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _EAPanel extends StatelessWidget {
  const _EAPanel({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _EAStyle.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF334154),
        ),
      ),
      child: child,
    );
  }
}

class _EAMetric extends StatelessWidget {
  const _EAMetric(
      this.label,
      this.value,
      this.tint,
      );

  final String label;
  final int value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return _EAPanel(
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.style_rounded,
            color: tint,
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              color: _EAStyle.ivory,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _EAStyle.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _eaInput(
    String label,
    IconData icon,
    ) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: _EAStyle.muted,
    ),
    prefixIcon: Icon(
      icon,
      color: _EAStyle.sky,
    ),
    filled: true,
    fillColor: _EAStyle.slate,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: Color(0xFF425063),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: _EAStyle.sky,
        width: 1.5,
      ),
    ),
  );
}

class _EAError extends StatelessWidget {
  const _EAError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: _EAStyle.coral,
              size: 45,
            ),
            const SizedBox(height: 10),
            const Text(
              'Could not load learning data',
              style: TextStyle(
                color: _EAStyle.ivory,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _EAStyle.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _eaMessage(
    BuildContext context,
    String message,
    ) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
}
