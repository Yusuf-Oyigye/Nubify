
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/nubi_service.dart';
import '../widgets/nubi_intro_video.dart';
import 'chat_screen.dart';
import 'nubi/nubi_learning_screens.dart';
import 'nubi/nubi_mindrush_screen.dart';

class NUBAiTutorScreen extends StatefulWidget {
  const NUBAiTutorScreen({super.key});

  @override
  State<NUBAiTutorScreen> createState() =>
      _NUBAiTutorScreenState();
}

class _NUBAiTutorScreenState
    extends State<NUBAiTutorScreen> {
  static const blue = Color(0xFF29B6F6);

  final TextEditingController _controller =
  TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _send() {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      _message('Type a question first.');
      return;
    }

    _open(
      NubiTutorScreen(initialQuestion: text),
    );
  }

  Future<void> _upload(bool image) async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final file = await FilePicker.pickFile(
        type: image ? FileType.image : FileType.any,
      );

      if (!mounted || file == null) return;

      final name = file.name.toLowerCase();
      final allowed = image
          ? ['.jpg', '.jpeg', '.png']
          : ['.pdf', '.docx', '.pptx', '.txt'];

      if (!allowed.any(name.endsWith)) {
        throw StateError(
          'Unsupported file format.',
        );
      }

      if (image) {
        _message(
          'Photo analysis requires the image '
              'processing backend. No photo uploaded.',
        );
        return;
      }

      final result =
      await NubiService.importFile(file);

      if (!mounted) return;

      final sourceId = result['sourceId'] as String;

      _message('Lecture added to My Deck.');

      _open(
        NubiTutorScreen(sourceId: sourceId),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString();

      if (message.contains('already-exists')) {
        _duplicateDialog();
      } else {
        _message(message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _duplicateDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'This Lecture Already Exists',
        ),
        content: const Text(
          'You have already added this lecture '
              'to NUBi. Open My Deck to continue '
              'learning or manage the old copy.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _open(const NubiDeckScreen());
            },
            child: const Text('View My Deck'),
          ),
        ],
      ),
    );
  }

  Widget _feature(
      String title,
      String subtitle,
      IconData icon,
      Color a,
      Color b,
      VoidCallback action,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            gradient: LinearGradient(
              colors: [a, b],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white),
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _panel({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor:
          blue.withValues(alpha: 0.12),
          child: Icon(icon, color: blue),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(description),
        trailing:
        const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = NubiService.uid;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16, 14, 16, 30,
      ),
      children: [
        const NubiIntroVideo(),

        const SizedBox(height: 23),

        Text(
          'What shall we study today? ✨',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(23),
            side: BorderSide(
              color: blue.withValues(alpha: .25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Ask NUBi anything...',
                    border: InputBorder.none,
                    suffixIcon: IconButton.filled(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: _send,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _upload(false),
                      icon: const Icon(
                        Icons.attach_file,
                        size: 17,
                      ),
                      label: const Text('Upload File'),
                    ),
                    TextButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _upload(true),
                      icon: const Icon(
                        Icons.image_outlined,
                        size: 17,
                      ),
                      label: const Text('Photo'),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More learning tools',
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                      ),
                      onSelected: (value) {
                        if (value == 'groups') {
                          _open(const ChatScreen());
                        } else {
                          _open(const NubiDeckScreen());
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'deck',
                          child: Text('My Deck'),
                        ),
                        PopupMenuItem(
                          value: 'groups',
                          child: Text('Study Groups'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_loading)
                  const LinearProgressIndicator(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 7),

        Text(
          'Learn Smart. Challenge Friends. Level Up.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelSmall,
        ),

        const SizedBox(height: 27),
        _sectionTitle('Explore NUBi'),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics:
          const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.42,
          children: [
            _feature(
              'My Deck',
              'Your learning space',
              Icons.auto_stories_rounded,
              const Color(0xFF14B8A6),
              const Color(0xFF4338CA),
                  () => _open(const NubiDeckScreen()),
            ),
            _feature(
              'MindRush',
              'Challenge friends',
              Icons.bolt_rounded,
              const Color(0xFFD97706),
              const Color(0xFF7C3AED),
                  () => _open(const NubiMindrushScreen()),
            ),
            _feature(
              'Flashcards',
              'Remember more',
              Icons.style_rounded,
              const Color(0xFF06B6D4),
              blue,
                  () => _open(
                const NubiDeckScreen(
                  initialTab: 3,
                ),
              ),
            ),
            _feature(
              'MCQs',
              'Test your knowledge',
              Icons.quiz_rounded,
              const Color(0xFF4338CA),
              const Color(0xFF10B981),
                  () => _open(
                const NubiDeckScreen(
                  initialTab: 4,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 27),
        _sectionTitle('Continue Learning'),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: NubiService.sources
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text(
                'Could not load saved lessons.',
              );
            }
            if (!snap.hasData) {
              return const LinearProgressIndicator();
            }

            final docs = snap.data!.docs
                .where((d) =>
            d.data()['status'] == 'ready')
                .toList();

            if (docs.isEmpty) {
              return _panel(
                title: 'Start your first lesson',
                description:
                'Upload a lecture or ask NUBi '
                    'a question to begin.',
                icon: Icons.menu_book,
                onTap: () => _open(
                  const NubiDeckScreen(),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                return _panel(
                  title: (data['title'] ?? 'Lecture')
                      .toString(),
                  description:
                  'Tap to resume your lesson',
                  icon: Icons.play_circle_outline,
                  onTap: () => _open(
                    NubiTutorScreen(
                      sourceId: doc.id,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 27),
        _sectionTitle('My Progress'),

        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: NubiService.progress.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final xp = (data?['lifetime'] ?? 0);
            return _panel(
              title: '$xp NUBi XP',
              description:
              'View your verified learning progress',
              icon: Icons.insights_rounded,
              onTap: () => _open(
                const NubiProgressScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 27),
        _sectionTitle('Study Groups'),

        _panel(
          title: 'Study better together',
          description:
          'Open existing Nubify group chats',
          icon: Icons.groups_rounded,
          onTap: () => _open(
            const ChatScreen(),
          ),
        ),

        const SizedBox(height: 27),
        _sectionTitle('🏆 NUBi Leaderboards'),

        _panel(
          title: 'My Faculty | University',
          description:
          'View verified academic rankings',
          icon: Icons.emoji_events_rounded,
          onTap: () => _open(
            const NubiLeaderboardScreen(),
          ),
        ),
      ],
    );
  }
}
