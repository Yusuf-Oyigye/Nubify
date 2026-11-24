
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/nubi/nubi_service.dart';
import '../../widgets/nubi/nubi_intro_video.dart';
import 'nubi_learning_screens.dart';
import 'nubi_mindrush_screen.dart';
import '../../l10n/nubify_text.dart';

class NUBAiTutorScreen extends StatefulWidget {
  const NUBAiTutorScreen({super.key});

  @override
  State<NUBAiTutorScreen> createState() =>
      _NUBAiTutorScreenState();
}

class _NUBAiTutorScreenState
    extends State<NUBAiTutorScreen> {
  static const blue = Color(0xFF29B6F6);
  static const navy = Color(0xFF14286B);

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
      _message(context.tr('Type a question first.'));
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
          context.tr('Unsupported file format.'),
        );
      }

      if (image) {
        _message(
          context.tr('Photo analysis requires the image '
              'processing backend. No photo uploaded.'),
        );
        return;
      }

      final result =
      await NubiService.importFile(file);

      if (!mounted) return;

      final sourceId = result['sourceId'] as String;

      _message(context.tr('Lecture added to My Deck.'));

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
        title: Text(context.tr('This Lecture Already Exists'),
        ),
        content: Text(context.tr('You have already added this lecture '
              'to NUBi. Open My Deck to continue '
              'learning or manage the old copy.'),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _open(const NubiDeckScreen());
            },
            child: Text(context.tr('View My Deck')),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16, 14, 16, 30,
      ),
      children: [
        const NubiIntroVideo(),

        const SizedBox(height: 23),

        Text(context.tr('What shall we study today? ✨'),
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
                    hintText: context.tr('Ask NUBi anything...'),
                    border: InputBorder.none,
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
                      label: Text(context.tr('Upload File')),
                    ),
                    TextButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _upload(true),
                      icon: const Icon(
                        Icons.image_outlined,
                        size: 17,
                      ),
                      label: Text(context.tr('Photo')),
                    ),
                    const Spacer(),
                    // Navy send button, on the same line as
                    // Upload File and Photo.
                    IconButton.filled(
                      tooltip: context.tr('Ask NUBi'),
                      style: IconButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: _send,
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

        Text(context.tr('Learn Smart. Challenge Friends. Level Up.'),
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelSmall,
        ),

        const SizedBox(height: 27),
        _sectionTitle(context.tr('Explore NUBi')),

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
              context.tr('My Deck'),
              context.tr('Your learning space'),
              Icons.auto_stories_rounded,
              const Color(0xFF14B8A6),
              const Color(0xFF4338CA),
                  () => _open(const NubiDeckScreen()),
            ),
            _feature(
              context.tr('MindRush'),
              context.tr('Challenge friends'),
              Icons.bolt_rounded,
              const Color(0xFFD97706),
              const Color(0xFF7C3AED),
                  () => _open(const NubiMindrushScreen()),
            ),
            _feature(
              context.tr('Flashcards'),
              context.tr('Remember more'),
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
              context.tr('MCQs'),
              context.tr('Test your knowledge'),
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
        _sectionTitle(context.tr('Continue Learning')),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: NubiService.sources
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(context.tr('Could not load saved lessons.'),
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
                title: context.tr('Start your first lesson'),
                description:
                context.tr('Upload a lecture or ask NUBi '
                    'a question to begin.'),
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
                  title: (data['title'] ?? context.tr('Lecture'))
                      .toString(),
                  description:
                  context.tr('Tap to resume your lesson'),
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
        _sectionTitle(context.tr('My Progress')),

        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: NubiService.progress.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final xp = (data?['lifetime'] ?? 0);
            return _panel(
              title: '$xp NUBi XP',
              description:
              context.tr('View your verified learning progress'),
              icon: Icons.insights_rounded,
              onTap: () => _open(
                const NubiProgressScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 27),
        _sectionTitle('🏆 NUBi Leaderboards'),

        _panel(
          title: context.tr('My Faculty | University'),
          description:
          context.tr('View verified academic rankings'),
          icon: Icons.emoji_events_rounded,
          onTap: () => _open(
            const NubiLeaderboardScreen(),
          ),
        ),
      ],
    );
  }
}
