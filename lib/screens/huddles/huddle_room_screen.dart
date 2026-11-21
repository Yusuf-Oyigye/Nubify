import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;

import '../../models/huddles/huddle.dart';
import '../../services/huddles/huddle_service.dart';
import '../../services/huddles/huddle_session.dart';
import '../../widgets/huddles/huddle_ui.dart';
import '../../widgets/profile/report_user_dialog.dart';
import 'huddle_chat_sheet.dart';
import 'huddle_ended_screen.dart';
import 'huddle_invite_sheet.dart';
import 'huddle_people_sheet.dart';

//===================================================
// NUB HUDDLES — LIVE ROOM
//===================================================

class HuddleRoomScreen extends StatefulWidget {
  const HuddleRoomScreen({super.key, required this.huddleId});

  final String huddleId;

  static Route<void> route(String huddleId) => MaterialPageRoute<void>(
    builder: (_) => HuddleRoomScreen(huddleId: huddleId),
  );

  @override
  State<HuddleRoomScreen> createState() => _HuddleRoomScreenState();
}

class _HuddleRoomScreenState extends State<HuddleRoomScreen> {
  final HuddleService _service = HuddleService.instance;
  final HuddleSession _session = HuddleSession.instance;

  late final Stream<Huddle?> _huddle = _service.watchHuddle(widget.huddleId);
  late final Stream<List<HuddleParticipant>> _people = _service
      .watchParticipants(widget.huddleId);

  StreamSubscription<HuddleReaction>? _reactionSub;
  final List<HuddleReaction> _flying = <HuddleReaction>[];

  String? _joinError;
  bool _showEmojis = false;
  bool _leaving = false;
  bool _endedShown = false;
  HuddleRole? _lastRole;

  String get _id => widget.huddleId;
  bool get _inThisHuddle => _session.huddleId == _id;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    _reactionSub = _session.reactions.listen(_onReaction);

    if (!_session.isIn(_id)) {
      _join();
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _reactionSub?.cancel();
    super.dispose();
  }

  //===================================================
  // JOIN (as a listener)
  //===================================================

  Future<void> _join() async {
    setState(() => _joinError = null);

    try {
      final HuddleTicket ticket = await _service.join(_id);
      final Huddle? huddle = await _service.getHuddle(_id);
      await _session.start(ticket, title: huddle?.title ?? 'Huddle');
    } on HuddleException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.ended) {
        _showEnded(null, null);
        return;
      }
      setState(() => _joinError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
              () => _joinError =
              _session.endMessage ?? 'Could not connect to the Huddle.',
        );
      }
    }
  }

  void _onSession() {
    if (!mounted || _leaving) {
      return;
    }
    if (_inThisHuddle && _session.connection == HuddleConnection.ended) {
      _showEnded(null, _session.endMessage);
      return;
    }
    setState(() {});
  }

  void _onReaction(HuddleReaction reaction) {
    if (!mounted) {
      return;
    }
    setState(() {
      _flying.add(reaction);
      if (_flying.length > 24) {
        _flying.removeAt(0);
      }
    });
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _flying.remove(reaction));
      }
    });
  }

  void _showEnded(Huddle? huddle, String? message) {
    if (_endedShown) {
      return;
    }
    _endedShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _session.reset();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HuddleEndedScreen(huddle: huddle, message: message),
        ),
      );
    });
  }

  //===================================================
  // HELPERS
  //===================================================

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _act(
      String action, {
        String? target,
        String? done,
        Map<String, Object?> extra = const {},
      }) async {
    try {
      await _service.action(_id, action, targetUid: target, extra: extra);
      if (done != null && mounted) {
        _snack(done);
      }
    } on HuddleException catch (error) {
      if (mounted) {
        _snack(error.message);
      }
    }
  }

  Future<void> _media(Future<String?> Function() task) async {
    final String? problem = await task();
    if (problem != null && mounted) {
      _snack(problem);
    }
  }

  // Tells people when their role changes.
  void _watchRole(HuddleRole role) {
    final HuddleRole? before = _lastRole;
    _lastRole = role;
    if (before == null || before == role) {
      return;
    }

    final String message = switch (role) {
      HuddleRole.host => 'You are now the host of this Huddle.',
      HuddleRole.coHost => 'You are now a co-host.',
      HuddleRole.speaker when before == HuddleRole.listener =>
      "You're a speaker. Your mic is off. Tap Unmute when you're ready.",
      HuddleRole.speaker => 'You are a speaker.',
      HuddleRole.listener => 'You are now listening.',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _snack(message);
      }
    });
  }

  HuddleParticipant? _find(List<HuddleParticipant> people, String uid) {
    for (final HuddleParticipant person in people) {
      if (person.uid == uid) {
        return person;
      }
    }
    return null;
  }

  Participant? _live(String uid) {
    final Room? room = _inThisHuddle ? _session.room : null;
    if (room == null) {
      return null;
    }
    if (room.localParticipant?.identity == uid) {
      return room.localParticipant;
    }
    return room.remoteParticipants[uid];
  }

  VideoTrack? _video(String uid, TrackSource source) {
    final TrackPublication? publication = _live(
      uid,
    )?.getTrackPublicationBySource(source);
    final Track? track = publication?.track;
    if (publication == null || publication.muted || track is! VideoTrack) {
      return null;
    }
    return track;
  }

  //===================================================
  // LEAVE / MINIMISE
  //===================================================

  void _minimise() => Navigator.of(context).maybePop();

  Future<void> _leave(HuddleRole role) async {
    if (role != HuddleRole.host) {
      await _leaveNow();
      return;
    }

    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HuddleColors.stageSoft,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.stop_circle_rounded,
                color: HuddleColors.live,
              ),
              title: const Text(
                'End Huddle for everyone',
                style: TextStyle(
                  color: HuddleColors.live,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, 'end'),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.white70),
              title: const Text(
                'Leave for now',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'The Huddle stays live. If you are not back in 3 minutes, a co-host takes over.',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: () => Navigator.pop(sheetContext, 'leave'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    if (choice == 'leave') {
      await _leaveNow();
    } else if (choice == 'end') {
      await _confirmEnd();
    }
  }

  Future<void> _confirmEnd() async {
    final bool? end = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Huddle for everyone?'),
        content: const Text(
          'Everyone will be disconnected and the Huddle will close.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HuddleColors.live),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('End Huddle'),
          ),
        ],
      ),
    );
    if (end != true || !mounted) {
      return;
    }
    final String? problem = await _session.end();
    if (problem != null && mounted) {
      _snack(problem);
    }
  }

  Future<void> _leaveNow() async {
    _leaving = true;
    await _session.leave();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HuddleColors.stage,
        body: StreamBuilder<Huddle?>(
          stream: _huddle,
          builder: (context, huddleSnap) {
            final Huddle? huddle = huddleSnap.data;
            final bool loaded =
                huddleSnap.connectionState == ConnectionState.active;

            if (loaded && (huddle == null || !huddle.isLive)) {
              _showEnded(huddle, _session.endMessage);
              return const SizedBox.shrink();
            }
            if (huddle == null) {
              return const _Centered(text: 'Opening Huddle…');
            }

            return StreamBuilder<List<HuddleParticipant>>(
              stream: _people,
              builder: (context, peopleSnap) {
                final List<HuddleParticipant> people =
                    peopleSnap.data ?? const <HuddleParticipant>[];
                final HuddleParticipant? me = _find(people, _service.uid);
                final HuddleRole role = me?.role ?? HuddleRole.listener;
                if (me != null) {
                  _watchRole(role);
                }

                return SafeArea(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _buildTopBar(huddle, role),
                          _buildStatus(),
                          if (me != null &&
                              me.hasSpeakerInvite &&
                              role == HuddleRole.listener)
                            _SpeakerInviteBanner(
                              inviter: me.speakerInviteByName,
                              onAccept: () => _act('acceptSpeakerInvite'),
                              onDecline: () => _act('declineSpeakerInvite'),
                            ),
                          Expanded(child: _buildStage(huddle, people)),
                          if (_showEmojis) _buildEmojiBar(),
                          _buildControls(huddle, people, me, role),
                        ],
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _ReactionsLayer(reactions: _flying),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  //===================================================
  // TOP BAR
  //===================================================

  Widget _buildTopBar(Huddle huddle, HuddleRole role) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Minimise',
            onPressed: _minimise,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  huddle.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const HuddleLivePill(small: true),
                    const SizedBox(width: 6),
                    _LiveClock(startedAt: huddle.startedAt),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 13,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${huddle.participantCount}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: () => _openMore(huddle, role),
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HuddleColors.live.withValues(alpha: .16),
              foregroundColor: HuddleColors.live,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => _leave(role),
            child: const Text(
              'Leave',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // CONNECTION STATUS — never an endless spinner
  //===================================================

  Widget _buildStatus() {
    if (_joinError != null) {
      return _StatusCard(
        icon: Icons.error_outline_rounded,
        color: HuddleColors.live,
        text: _joinError!,
        action: 'Try again',
        onAction: _join,
      );
    }

    if (!_inThisHuddle) {
      return const _StatusCard(
        icon: Icons.wifi_tethering_rounded,
        color: HuddleColors.sky,
        text: 'Connecting…',
        busy: true,
      );
    }

    return switch (_session.connection) {
      HuddleConnection.connecting => const _StatusCard(
        icon: Icons.wifi_tethering_rounded,
        color: HuddleColors.sky,
        text: 'Connecting…',
        busy: true,
      ),
      HuddleConnection.reconnecting => const _StatusCard(
        icon: Icons.sync_rounded,
        color: HuddleColors.host,
        text: 'Reconnecting…',
        busy: true,
      ),
      HuddleConnection.poor => const _StatusCard(
        icon: Icons.network_check_rounded,
        color: HuddleColors.host,
        text: 'Poor connection. Video may pause; audio comes first.',
      ),
      HuddleConnection.failed => _StatusCard(
        icon: Icons.portable_wifi_off_rounded,
        color: HuddleColors.live,
        text: _session.endMessage ?? 'You lost connection to the Huddle.',
        action: _session.endMessage == 'You were removed from this Huddle.'
            ? null
            : 'Rejoin',
        onAction: _join,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  //===================================================
  // STAGE — speakers, listeners or a presentation
  //===================================================

  Widget _buildStage(Huddle huddle, List<HuddleParticipant> people) {
    final List<HuddleParticipant> speakers = people
        .where((p) => p.role.canSpeak)
        .toList();
    final List<HuddleParticipant> listeners = people
        .where((p) => !p.role.canSpeak)
        .toList();

    // Whoever is presenting gets the big area.
    String sharer = huddle.screenSharerId;
    VideoTrack? screen = sharer.isEmpty
        ? null
        : _video(sharer, TrackSource.screenShareVideo);
    if (screen == null) {
      for (final HuddleParticipant person in speakers) {
        screen = _video(person.uid, TrackSource.screenShareVideo);
        if (screen != null) {
          sharer = person.uid;
          break;
        }
      }
    }

    if (screen != null || (_session.sharingScreen && _inThisHuddle)) {
      final HuddleParticipant? presenter = _find(people, sharer);
      return _buildPresentation(
        screen: _session.sharingScreen ? null : screen,
        presenterName: _session.sharingScreen
            ? 'You'
            : presenter?.name ?? huddle.screenSharerName,
        speakers: speakers,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tileWidth = (constraints.maxWidth - 32 - 20) / 3;
        int videoTiles = 0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            if (huddle.description.isNotEmpty || huddle.topic.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  [
                    if (huddle.topic.isNotEmpty) '#${huddle.topic}',
                    huddle.description,
                  ].where((s) => s.isNotEmpty).join('  ·  '),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ),
            const _Label('On stage'),
            Wrap(
              spacing: 10,
              runSpacing: 14,
              children: [
                for (final HuddleParticipant person in speakers)
                  Builder(
                    builder: (_) {
                      final VideoTrack? camera = videoTiles < 6
                          ? _video(person.uid, TrackSource.camera)
                          : null;
                      if (camera != null) {
                        videoTiles++;
                      }
                      return _SpeakerTile(
                        person: person,
                        width: tileWidth,
                        camera: camera,
                        speaking: _session.speakingIds.contains(person.uid),
                        muted:
                        !(_live(person.uid)?.isMicrophoneEnabled() ??
                            false),
                        mirror: person.uid == _service.uid,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 22),
            _Label('Listening · ${listeners.length}'),
            if (listeners.isEmpty)
              const Text(
                'No listeners yet. Share the Huddle to bring people in.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 10,
                children: [
                  for (final HuddleParticipant person in listeners.take(60))
                    _ListenerTile(
                      person: person,
                      width: (constraints.maxWidth - 32 - 24) / 5,
                    ),
                  if (listeners.length > 60)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '+${listeners.length - 60} more',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildPresentation({
    required VideoTrack? screen,
    required String presenterName,
    required List<HuddleParticipant> speakers,
  }) {
    final bool mine = screen == null;

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: HuddleColors.stageLine),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: mine
                      ? const _SharingYourScreen()
                      : VideoTrackRenderer(screen, fit: VideoViewFit.contain),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.present_to_all_rounded,
                          size: 15,
                          color: HuddleColors.sky,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mine
                              ? 'You are presenting'
                              : '$presenterName is presenting',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (mine)
                  Positioned(
                    right: 10,
                    top: 8,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: HuddleColors.live,
                      ),
                      onPressed: () => _media(() async {
                        await _session.stopScreenShare();
                        return null;
                      }),
                      icon: const Icon(
                        Icons.stop_screen_share_rounded,
                        size: 18,
                      ),
                      label: const Text('Stop sharing'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final HuddleParticipant person in speakers)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      HuddleAvatar(
                        name: person.name,
                        photoUrl: person.photoUrl,
                        size: 46,
                        speaking: _session.speakingIds.contains(person.uid),
                        muted:
                        !(_live(person.uid)?.isMicrophoneEnabled() ??
                            false),
                      ),
                      SizedBox(
                        width: 62,
                        child: Text(
                          person.name.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  //===================================================
  // REACTIONS
  //===================================================

  Widget _buildEmojiBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: HuddleColors.stageCard,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: HuddleColors.stageLine),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final String emoji in huddleReactionEmojis)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                _session.sendReaction(emoji);
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
        ],
      ),
    );
  }

  //===================================================
  // CONTROLS
  //===================================================

  Widget _buildControls(
      Huddle huddle,
      List<HuddleParticipant> people,
      HuddleParticipant? me,
      HuddleRole role,
      ) {
    final bool connected =
        _inThisHuddle &&
            (_session.connection == HuddleConnection.connected ||
                _session.connection == HuddleConnection.poor);
    final int requests = people
        .where((p) => p.handRaised && p.role == HuddleRole.listener)
        .length;
    final bool cameraAllowed = role == HuddleRole.host || huddle.allowVideo;
    final bool screenAllowed =
        role == HuddleRole.host || huddle.allowScreenShare;

    final List<Widget> buttons = [
      if (role.canSpeak) ...[
        _ControlButton(
          icon: _session.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: _session.micOn ? 'Mute' : 'Unmute',
          active: _session.micOn,
          enabled: connected,
          onTap: () => _media(_session.toggleMic),
        ),
        if (cameraAllowed)
          _ControlButton(
            icon: _session.cameraOn
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: 'Camera',
            active: _session.cameraOn,
            enabled: connected,
            onTap: () => _media(_session.toggleCamera),
          ),
        if (screenAllowed)
          _ControlButton(
            icon: _session.sharingScreen
                ? Icons.stop_screen_share_rounded
                : Icons.present_to_all_rounded,
            label: _session.sharingScreen ? 'Stop' : 'Present',
            active: _session.sharingScreen,
            enabled: connected,
            onTap: _toggleScreenShare,
          ),
      ] else
        _ControlButton(
          icon: Icons.back_hand_rounded,
          label: me?.handRaised == true ? 'Cancel' : 'Raise hand',
          active: me?.handRaised == true,
          enabled: connected,
          onTap: () {
            if (me?.handRaised == true) {
              _act('lowerHand', done: 'Request cancelled.');
            } else if (!huddle.allowSpeakerRequests) {
              _snack('The host has turned off speaker requests.');
            } else {
              _act(
                'raiseHand',
                done: 'Request sent. The host will see your hand.',
              );
            }
          },
        ),
      _ControlButton(
        icon: Icons.emoji_emotions_outlined,
        label: 'React',
        active: _showEmojis,
        enabled: connected,
        onTap: () => setState(() => _showEmojis = !_showEmojis),
      ),
      _ControlButton(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Chat',
        onTap: () => HuddleChatSheet.show(context, huddleId: _id, role: role),
      ),
      _ControlButton(
        icon: Icons.groups_rounded,
        label: 'People',
        badge: role.canManage ? requests : 0,
        onTap: () =>
            HuddlePeopleSheet.show(context, huddle: huddle, myRole: role),
      ),
      if (!role.canSpeak)
        _ControlButton(
          icon: Icons.ios_share_rounded,
          label: 'Share',
          onTap: () => HuddleInviteSheet.show(context, huddle: huddle),
        ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      decoration: const BoxDecoration(
        color: HuddleColors.stageSoft,
        border: Border(top: BorderSide(color: HuddleColors.stageLine)),
      ),
      child: Row(
        children: [
          for (final Widget button in buttons) Expanded(child: button),
        ],
      ),
    );
  }

  Future<void> _toggleScreenShare() async {
    if (_session.sharingScreen) {
      await _session.stopScreenShare();
      return;
    }

    // Privacy warning before anything is captured.
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.present_to_all_rounded),
        title: const Text('Share your screen?'),
        content: const Text(
          'Everything visible on your screen, including notifications and '
              'other apps you open, can be seen by everyone in this Huddle. '
              'Your voice keeps working while you present.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start sharing'),
          ),
        ],
      ),
    );
    if (go == true) {
      await _media(_session.startScreenShare);
    }
  }

  //===================================================
  // MORE MENU
  //===================================================

  Future<void> _openMore(Huddle huddle, HuddleRole role) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HuddleColors.stageSoft,
      showDragHandle: true,
      builder: (sheetContext) {
        Widget item(IconData icon, String text, String value, {Color? color}) {
          return ListTile(
            leading: Icon(icon, color: color ?? Colors.white70),
            title: Text(text, style: TextStyle(color: color ?? Colors.white)),
            onTap: () => Navigator.pop(sheetContext, value),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item(Icons.ios_share_rounded, 'Invite or share', 'share'),
                if (_session.cameraOn)
                  item(Icons.cameraswitch_rounded, 'Switch camera', 'flip'),
                if (role == HuddleRole.speaker || role == HuddleRole.coHost)
                  item(Icons.headphones_rounded, 'Leave as Speaker', 'listen'),
                if (role == HuddleRole.host)
                  item(Icons.tune_rounded, 'Huddle settings', 'settings'),
                if (role != HuddleRole.host)
                  item(
                    Icons.flag_outlined,
                    'Report this Huddle',
                    'report',
                    color: HuddleColors.live,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) {
      return;
    }
    switch (choice) {
      case 'share':
        await HuddleInviteSheet.show(context, huddle: huddle);
      case 'flip':
        await _session.flipCamera();
      case 'listen':
        await _media(_session.leaveAsSpeaker);
      case 'settings':
        await _openSettings(huddle);
      case 'report':
        await showReportUserDialog(context: context, targetUid: huddle.hostId);
    }
  }

  Future<void> _openSettings(Huddle huddle) async {
    bool chat = huddle.chatEnabled;
    bool requests = huddle.allowSpeakerRequests;
    bool video = huddle.allowVideo;
    bool screen = huddle.allowScreenShare;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: HuddleColors.stageSoft,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          Widget toggle(
              String title,
              bool value,
              String key,
              void Function(bool) set,
              ) {
            return SwitchListTile(
              value: value,
              activeThumbColor: HuddleColors.sky,
              title: Text(title, style: const TextStyle(color: Colors.white)),
              onChanged: (next) {
                setSheet(() => set(next));
                _act('updateSettings', extra: {key: next});
              },
            );
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                toggle('Live chat', chat, 'chatEnabled', (v) => chat = v),
                toggle(
                  'Speaker requests (raise hand)',
                  requests,
                  'allowSpeakerRequests',
                      (v) => requests = v,
                ),
                toggle(
                  'Speakers can use camera',
                  video,
                  'allowVideo',
                      (v) => video = v,
                ),
                toggle(
                  'Speakers can share screen',
                  screen,
                  'allowScreenShare',
                      (v) => screen = v,
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

//===================================================
// SMALL PIECES
//===================================================

class _Centered extends StatelessWidget {
  const _Centered({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: HuddleColors.sky),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.startedAt});

  final DateTime? startedAt;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? start = widget.startedAt;
    final Duration elapsed = start == null
        ? Duration.zero
        : DateTime.now().difference(start);

    return Text(
      formatHuddleDuration(elapsed.isNegative ? Duration.zero : elapsed),
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.text,
    this.busy = false,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool busy;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          if (busy)
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                action!,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpeakerInviteBanner extends StatelessWidget {
  const _SpeakerInviteBanner({
    required this.inviter,
    required this.onAccept,
    required this.onDecline,
  });

  final String inviter;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [HuddleColors.skyDeep, Color(0xFF1B4E86)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${inviter.isEmpty ? 'The host' : inviter} invited you to speak',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your mic stays off until you tap Unmute.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: HuddleColors.skyDeep,
                  ),
                  onPressed: onAccept,
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeakerTile extends StatelessWidget {
  const _SpeakerTile({
    required this.person,
    required this.width,
    required this.camera,
    required this.speaking,
    required this.muted,
    required this.mirror,
  });

  final HuddleParticipant person;
  final double width;
  final VideoTrack? camera;
  final bool speaking;
  final bool muted;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final VideoTrack? video = camera;

    return SizedBox(
      width: width,
      child: Column(
        children: [
          if (video != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: width * 1.15,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: speaking
                      ? HuddleColors.speaking
                      : HuddleColors.stageLine,
                  width: speaking ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: VideoTrackRenderer(
                video,
                fit: VideoViewFit.cover,
                mirrorMode: mirror
                    ? VideoViewMirrorMode.mirror
                    : VideoViewMirrorMode.off,
              ),
            )
          else
            HuddleAvatar(
              name: person.name,
              photoUrl: person.photoUrl,
              size: (width - 18).clamp(40, 76),
              speaking: speaking,
              muted: muted,
            ),
          const SizedBox(height: 6),
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          HuddleRoleBadge(role: person.role),
        ],
      ),
    );
  }
}

class _ListenerTile extends StatelessWidget {
  const _ListenerTile({required this.person, required this.width});

  final HuddleParticipant person;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          HuddleAvatar(
            name: person.name,
            photoUrl: person.photoUrl,
            size: (width - 16).clamp(30, 52),
            handRaised: person.handRaised,
          ),
          const SizedBox(height: 4),
          Text(
            person.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SharingYourScreen extends StatelessWidget {
  const _SharingYourScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: HuddleColors.stageCard,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.screen_share_rounded,
                color: HuddleColors.sky,
                size: 44,
              ),
              SizedBox(height: 12),
              Text(
                'You are sharing your screen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Open your slides, PDF or any app. Everything on your screen '
                    'is visible to the Huddle.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final Color color = !enabled
        ? Colors.white24
        : active
        ? HuddleColors.stage
        : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: HuddleColors.live,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active && enabled
                      ? HuddleColors.sky
                      : HuddleColors.stageCard,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white24,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Emojis float up from the bottom and fade away.
class _ReactionsLayer extends StatelessWidget {
  const _ReactionsLayer({required this.reactions});

  final List<HuddleReaction> reactions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          for (final HuddleReaction reaction in reactions)
            TweenAnimationBuilder<double>(
              key: ValueKey<int>(reaction.id),
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 2400),
              builder: (context, t, child) {
                final double lane = (reaction.id * 37 % 60) / 100;
                return Positioned(
                  right: 24 + lane * constraints.maxWidth * .3,
                  bottom: 90 + t * constraints.maxHeight * .45,
                  child: Opacity(
                    opacity: (1 - t).clamp(0, 1),
                    child: Transform.scale(scale: .8 + t * .4, child: child),
                  ),
                );
              },
              child: Text(reaction.emoji, style: const TextStyle(fontSize: 30)),
            ),
        ],
      ),
    );
  }
}