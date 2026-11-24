import 'package:flutter/material.dart';

import '../../models/huddles/huddle.dart';
import '../../services/huddles/huddle_service.dart';
import '../../services/huddles/huddle_session.dart';
import '../../widgets/huddles/huddle_ui.dart';
import 'huddle_launcher.dart';
import 'huddle_room_screen.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// NUB HUDDLES — START A HUDDLE
//===================================================

const List<String> _topics = [
  'Study session',
  'Tutorial',
  'Lecture',
  'Project meeting',
  'Club meeting',
  'Presentation',
  'Q&A',
  'Debate',
  'Campus talk',
  'Hangout',
];

class CreateHuddleScreen extends StatefulWidget {
  const CreateHuddleScreen({super.key});

  @override
  State<CreateHuddleScreen> createState() => _CreateHuddleScreenState();
}

class _CreateHuddleScreenState extends State<CreateHuddleScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();

  String _topic = '';
  bool _withVideo = false;
  HuddlePrivacy _privacy = HuddlePrivacy.everyone;
  bool _speakerRequests = true;
  bool _cameras = true;
  bool _screenShare = true;
  bool _chat = true;
  bool _starting = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final String title = _title.text.trim();
    if (title.length < 3) {
      _snack(context.tr('Give your Huddle a title.'));
      return;
    }

    setState(() => _starting = true);
    try {
      final HuddleTicket ticket = await HuddleService.instance.create(
        title: title,
        description: _description.text.trim(),
        topic: _topic,
        withVideo: _withVideo,
        privacy: _privacy,
        allowSpeakerRequests: _speakerRequests,
        allowVideo: _cameras,
        allowScreenShare: _screenShare,
        chatEnabled: _chat,
      );

      final HuddleSession session = HuddleSession.instance;
      if (session.isActive) {
        await session.leave();
      }
      await session.start(ticket, title: title);

      // Hosts who chose "Audio + video" start with camera
      // on; everyone else starts with everything off.
      if (_withVideo) {
        await session.toggleCamera();
      }

      if (mounted) {
        await Navigator.of(
          context,
        ).pushReplacement(HuddleRoomScreen.route(ticket.huddleId));
      }
    } on HuddleException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _starting = false);

      final String? existing = error.huddleId;
      if (existing != null) {
        await openHuddle(context, existing);
        return;
      }
      _snack(error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _starting = false);
        _snack(
          HuddleSession.instance.endMessage ?? context.tr('Could not start the Huddle.'),
        );
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    InputDecoration field(String label, String hint) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Start a Huddle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            TextField(
              controller: _title,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: field(context.tr('Title'), context.tr('e.g. Anatomy revision session')),
            ),
            TextField(
              controller: _description,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: field(
                context.tr('Description (optional)'),
                context.tr('What will you talk about?'),
              ),
            ),
            const SizedBox(height: 6),
            _Title(context.tr('Topic (optional)'), colors),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final String topic in _topics)
                  ChoiceChip(
                    label: Text(context.tr(topic)),
                    selected: _topic == topic,
                    onSelected: (on) =>
                        setState(() => _topic = on ? topic : ''),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _Title(context.tr('How do you want to start?'), colors),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.mic_rounded),
                  label: Text(context.tr('Audio only')),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.videocam_rounded),
                  label: Text(context.tr('Audio + video')),
                ),
              ],
              selected: {_withVideo},
              onSelectionChanged: (value) =>
                  setState(() => _withVideo = value.first),
            ),
            const SizedBox(height: 6),
            Text(context.tr('You can turn on video or share your screen any time during the Huddle.'),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            _Title(context.tr('Who can join'), colors),
            RadioGroup<HuddlePrivacy>(
              groupValue: _privacy,
              onChanged: (value) =>
                  setState(() => _privacy = value ?? _privacy),
              child: Column(
                children: [
                  for (final HuddlePrivacy privacy in HuddlePrivacy.values)
                    RadioListTile<HuddlePrivacy>(
                      contentPadding: EdgeInsets.zero,
                      value: privacy,
                      title: Text(privacy.label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Title(context.tr('In the Huddle'), colors),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _speakerRequests,
              onChanged: (v) => setState(() => _speakerRequests = v),
              title: Text(context.tr('Listeners can raise their hand to speak')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _cameras,
              onChanged: (v) => setState(() => _cameras = v),
              title: Text(context.tr('Speakers can use their camera')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _screenShare,
              onChanged: (v) => setState(() => _screenShare = v),
              title: Text(context.tr('Speakers can share their screen')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _chat,
              onChanged: (v) => setState(() => _chat = v),
              title: Text(context.tr('Live chat')),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: HuddleColors.sky,
                foregroundColor: HuddleColors.stage,
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: _starting ? null : _start,
              icon: _starting
                  ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.graphic_eq_rounded),
              label: Text(
                _starting ? context.tr('Starting…') : context.tr('Start Huddle'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(context.tr('Huddles are never recorded.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, this.colors);

  final String text;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}