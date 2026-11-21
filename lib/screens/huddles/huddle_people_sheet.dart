import 'package:flutter/material.dart';

import '../../models/huddle.dart';
import '../../services/huddle_service.dart';
import '../../widgets/huddle_ui.dart';
import '../../widgets/report_user_dialog.dart';

//===================================================
// NUB HUDDLES — PEOPLE PANEL
//
// Speaker requests, host, co-hosts, speakers and
// listeners, with the actions each role may use.
//===================================================

class HuddlePeopleSheet extends StatelessWidget {
  const HuddlePeopleSheet({
    super.key,
    required this.huddle,
    required this.myRole,
  });

  final Huddle huddle;
  final HuddleRole myRole;

  static Future<void> show(
      BuildContext context, {
        required Huddle huddle,
        required HuddleRole myRole,
      }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HuddleColors.stageSoft,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .82,
        child: HuddlePeopleSheet(huddle: huddle, myRole: myRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final HuddleService service = HuddleService.instance;

    return StreamBuilder<List<HuddleParticipant>>(
      stream: service.watchParticipants(huddle.id),
      builder: (context, snapshot) {
        final List<HuddleParticipant> people =
            snapshot.data ?? const <HuddleParticipant>[];

        List<HuddleParticipant> withRole(HuddleRole role) =>
            people.where((p) => p.role == role).toList();

        final List<HuddleParticipant> requests =
        people
            .where((p) => p.handRaised && p.role == HuddleRole.listener)
            .toList()
          ..sort((a, b) => a.handRaisedAt!.compareTo(b.handRaisedAt!));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              'People · ${people.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (myRole.canManage && requests.isNotEmpty) ...[
              const _Header('Requests to speak'),
              for (final HuddleParticipant person in requests)
                _RequestRow(huddleId: huddle.id, person: person),
            ],
            for (final HuddleRole role in HuddleRole.values)
              if (withRole(role).isNotEmpty) ...[
                _Header(
                  role == HuddleRole.host
                      ? 'Host'
                      : '${role.label}s · ${withRole(role).length}',
                ),
                for (final HuddleParticipant person in withRole(role))
                  _PersonRow(huddle: huddle, person: person, myRole: myRole),
              ],
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

Future<void> _act(
    BuildContext context,
    String huddleId,
    String action,
    String target, {
      String? done,
      Map<String, Object?> extra = const {},
    }) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await HuddleService.instance.action(
      huddleId,
      action,
      targetUid: target,
      extra: extra,
    );
    if (done != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(done), behavior: SnackBarBehavior.floating),
      );
    }
  } on HuddleException catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(error.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

//===================================================
// RAISED HAND
//===================================================

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.huddleId, required this.person});

  final String huddleId;
  final HuddleParticipant person;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: HuddleColors.host.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HuddleColors.host.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          HuddleAvatar(
            name: person.name,
            photoUrl: person.photoUrl,
            size: 38,
            handRaised: true,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              person.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                _act(context, huddleId, 'declineRequest', person.uid),
            child: const Text(
              'Decline',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HuddleColors.sky,
              foregroundColor: HuddleColors.stage,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _act(
              context,
              huddleId,
              'approveRequest',
              person.uid,
              done: '${person.name} can now speak.',
            ),
            child: const Text(
              'Accept',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// ONE PERSON + WHAT YOU CAN DO TO THEM
//===================================================

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.huddle,
    required this.person,
    required this.myRole,
  });

  final Huddle huddle;
  final HuddleParticipant person;
  final HuddleRole myRole;

  bool get _isMe => person.uid == HuddleService.instance.uid;

  // Mirrors the backend rule: co-hosts manage speakers
  // and listeners; only the host manages co-hosts.
  bool get _canModerate {
    if (_isMe) {
      return false;
    }
    if (myRole == HuddleRole.host) {
      return person.role != HuddleRole.host;
    }
    return myRole == HuddleRole.coHost &&
        (person.role == HuddleRole.speaker ||
            person.role == HuddleRole.listener);
  }

  @override
  Widget build(BuildContext context) {
    final bool host = myRole == HuddleRole.host;
    final List<(String, String)> actions = [
      if (_canModerate &&
          person.role == HuddleRole.listener &&
          !person.hasSpeakerInvite)
        ('inviteToSpeak', 'Invite to speak'),
      if (_canModerate && person.role.canSpeak) ...[
        ('muteSpeaker', 'Mute'),
        ('moveToListeners', 'Move to listeners'),
      ],
      if (_canModerate && huddle.screenSharerId == person.uid)
        ('stopScreenShare', 'Stop their presentation'),
      if (host && !_isMe && person.role != HuddleRole.coHost)
        ('makeCoHost', 'Make co-host'),
      if (host && person.role == HuddleRole.coHost)
        ('removeCoHost', 'Remove co-host'),
      if (host && !_isMe && person.role.canSpeak) ('makeHost', 'Make host'),
      if (_canModerate) ...[
        ('removeParticipant', 'Remove from Huddle'),
        ('block', 'Remove and block from Huddle'),
      ],
      ('profile', 'View profile'),
      if (!_isMe) ('report', 'Report'),
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: HuddleAvatar(
        name: person.name,
        photoUrl: person.photoUrl,
        size: 38,
        handRaised: person.handRaised,
      ),
      title: Text(
        _isMe ? '${person.name} (you)' : person.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Align(
        alignment: Alignment.centerLeft,
        child: person.hasSpeakerInvite
            ? const Text(
          'Invited to speak',
          style: TextStyle(color: HuddleColors.sky, fontSize: 12),
        )
            : HuddleRoleBadge(role: person.role),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
        onSelected: (value) => _run(context, value),
        itemBuilder: (_) => [
          for (final (String value, String label) in actions)
            PopupMenuItem<String>(
              value: value,
              child: Text(
                label,
                style: TextStyle(
                  color: value == 'block' || value == 'removeParticipant'
                      ? HuddleColors.live
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _run(BuildContext context, String value) async {
    final String id = huddle.id;

    switch (value) {
      case 'profile':
        await Navigator.of(
          context,
        ).pushNamed('/profile', arguments: person.uid);
      case 'report':
        await showReportUserDialog(context: context, targetUid: person.uid);
      case 'inviteToSpeak':
        await _act(
          context,
          id,
          value,
          person.uid,
          done: 'Invitation sent to ${person.name}.',
        );
      case 'makeHost':
        final bool? sure = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Make ${person.name} the host?'),
            content: const Text('You will become a co-host.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Make host'),
              ),
            ],
          ),
        );
        if (sure == true && context.mounted) {
          await _act(context, id, value, person.uid);
        }
      case 'block':
        await _act(
          context,
          id,
          'removeParticipant',
          person.uid,
          extra: {'block': true},
          done: '${person.name} was removed and blocked.',
        );
      default:
        await _act(context, id, value, person.uid);
    }
  }
}