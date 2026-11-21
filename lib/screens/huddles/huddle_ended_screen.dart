import 'package:flutter/material.dart';

import '../../models/huddles/huddle.dart';
import '../../widgets/huddles/huddle_ui.dart';

//===================================================
// "THIS HUDDLE HAS ENDED"
//
// Shown for old links instead of an error.
//===================================================

class HuddleEndedScreen extends StatelessWidget {
  const HuddleEndedScreen({super.key, this.huddle, this.message});

  // Null when the Huddle's details are gone.
  final Huddle? huddle;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final Huddle? h = huddle;
    final DateTime? started = h?.startedAt;
    final MaterialLocalizations local = MaterialLocalizations.of(context);

    return Scaffold(
      backgroundColor: HuddleColors.stage,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HuddleColors.sky.withValues(alpha: .12),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: HuddleColors.sky,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'This Huddle has ended',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (message != null && message != 'This Huddle has ended.') ...[
                  const SizedBox(height: 6),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
                if (h != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: HuddleColors.stageCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: HuddleColors.stageLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            HuddleAvatar(
                              name: h.hostName,
                              photoUrl: h.hostPhotoUrl,
                              size: 34,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Hosted by ${h.hostName}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (started != null)
                          _Fact(
                            icon: Icons.schedule_rounded,
                            text:
                            'Started ${local.formatMediumDate(started)}, '
                                '${local.formatTimeOfDay(TimeOfDay.fromDateTime(started))}',
                          ),
                        _Fact(
                          icon: Icons.timer_outlined,
                          text: 'Lasted ${formatHuddleDuration(h.elapsed)}',
                        ),
                        if (h.peakParticipants > 0)
                          _Fact(
                            icon: Icons.people_alt_outlined,
                            text: 'Up to ${h.peakParticipants} people joined',
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: HuddleColors.sky,
                    foregroundColor: HuddleColors.stage,
                    minimumSize: const Size(200, 48),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: HuddleColors.sky),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}