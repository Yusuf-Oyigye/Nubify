import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/huddle.dart';
import 'huddle_service.dart';

//===================================================
// CONNECTION STATES SHOWN TO PEOPLE
//===================================================

enum HuddleConnection {
  idle,
  connecting,
  connected,
  reconnecting,
  poor,
  ended,
  failed,
}

const List<String> huddleReactionEmojis = ['❤️', '👏', '😂', '🔥', '👍'];

class HuddleReaction {
  HuddleReaction(this.emoji, this.fromName) : id = _next++;

  static int _next = 0;

  final String emoji;
  final String fromName;
  final int id;
}

//===================================================
// NUB HUDDLES — LIVE SESSION
//
// One live Huddle at a time. It lives outside any
// screen, so you can minimise the Huddle and keep
// using Nubify without disconnecting.
//===================================================

class HuddleSession extends ChangeNotifier {
  HuddleSession._();

  static final HuddleSession instance = HuddleSession._();

  final HuddleService _service = HuddleService.instance;

  Room? _room;
  EventsListener<RoomEvent>? _events;

  String? huddleId;
  String title = '';
  HuddleConnection connection = HuddleConnection.idle;

  // Why the session stopped (ended, removed, lost).
  String? endMessage;

  bool micOn = false;
  bool cameraOn = false;
  bool sharingScreen = false;
  CameraPosition _cameraPosition = CameraPosition.front;
  Set<String> speakingIds = <String>{};

  final StreamController<HuddleReaction> _reactions =
  StreamController<HuddleReaction>.broadcast();

  Stream<HuddleReaction> get reactions => _reactions.stream;

  Room? get room => _room;

  bool get isActive =>
      huddleId != null &&
          (connection == HuddleConnection.connecting ||
              connection == HuddleConnection.connected ||
              connection == HuddleConnection.reconnecting ||
              connection == HuddleConnection.poor);

  bool isIn(String id) => isActive && huddleId == id;

  //===================================================
  // CONNECT
  //
  // Mic and camera stay OFF. Everyone starts by just
  // listening; nothing is sent until they choose to.
  //===================================================

  Future<void> start(HuddleTicket ticket, {required String title}) async {
    if (isIn(ticket.huddleId)) {
      return;
    }
    await _teardown();

    huddleId = ticket.huddleId;
    this.title = title;
    connection = HuddleConnection.connecting;
    endMessage = null;
    notifyListeners();

    final Room room = Room(
      roomOptions: const RoomOptions(
        // Only download video that is actually on screen,
        // at the size it is shown. Saves mobile data.
        adaptiveStream: true,
        // Stop sending video layers nobody is watching.
        dynacast: true,
        defaultAudioPublishOptions: AudioPublishOptions(dtx: true, red: true),
        defaultVideoPublishOptions: VideoPublishOptions(simulcast: true),
        defaultCameraCaptureOptions: CameraCaptureOptions(
          params: VideoParametersPresets.h540_169,
        ),
        defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
          params: VideoParametersPresets.screenShareH720FPS15,
        ),
      ),
    );
    _room = room;
    _events = room.createListener();
    _listen(_events!);

    try {
      await room
          .connect(ticket.url, ticket.token)
          .timeout(const Duration(seconds: 20));
      await AudioManager.instance.setSpeakerOutputPreferred(true);
      connection = HuddleConnection.connected;
      notifyListeners();
    } catch (_) {
      await _teardown();
      connection = HuddleConnection.failed;
      endMessage = 'Could not connect to the Huddle. Check your internet.';
      notifyListeners();
      rethrow;
    }
  }

  void _listen(EventsListener<RoomEvent> events) {
    events
      ..on<RoomReconnectingEvent>(
            (_) => _setConnection(HuddleConnection.reconnecting),
      )
      ..on<RoomReconnectedEvent>(
            (_) => _setConnection(HuddleConnection.connected),
      )
      ..on<RoomDisconnectedEvent>(_onDisconnected)
      ..on<ActiveSpeakersChangedEvent>((event) {
        speakingIds = event.speakers.map((p) => p.identity).toSet();
        notifyListeners();
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        if (event.participant is! LocalParticipant) {
          return;
        }
        final bool poor =
            event.connectionQuality == ConnectionQuality.poor ||
                event.connectionQuality == ConnectionQuality.lost;
        if (poor && connection == HuddleConnection.connected) {
          _setConnection(HuddleConnection.poor);
        } else if (!poor && connection == HuddleConnection.poor) {
          _setConnection(HuddleConnection.connected);
        }
      })
      ..on<ParticipantPermissionsUpdatedEvent>(_onPermissions)
      ..on<DataReceivedEvent>(_onData)
      ..on<TrackSubscribedEvent>((_) => notifyListeners())
      ..on<TrackUnsubscribedEvent>((_) => notifyListeners())
      ..on<TrackMutedEvent>(_onMuted)
      ..on<TrackUnmutedEvent>((_) => notifyListeners())
      ..on<LocalTrackPublishedEvent>((_) => notifyListeners())
      ..on<LocalTrackUnpublishedEvent>(_onLocalUnpublished)
      ..on<ParticipantConnectedEvent>((_) => notifyListeners())
      ..on<ParticipantDisconnectedEvent>((_) => notifyListeners());
  }

  void _setConnection(HuddleConnection value) {
    if (connection != value) {
      connection = value;
      notifyListeners();
    }
  }

  Future<void> _onDisconnected(RoomDisconnectedEvent event) async {
    if (event.reason == DisconnectReason.clientInitiated) {
      return;
    }

    endMessage = switch (event.reason) {
      DisconnectReason.roomDeleted => 'This Huddle has ended.',
      DisconnectReason.participantRemoved =>
      'You were removed from this Huddle.',
      DisconnectReason.duplicateIdentity =>
      'You joined this Huddle on another device.',
      _ => 'You lost connection to the Huddle.',
    };

    final bool ended = event.reason == DisconnectReason.roomDeleted;
    await _teardown();
    connection = ended ? HuddleConnection.ended : HuddleConnection.failed;
    notifyListeners();
  }

  // The host changed what you may send (for example you
  // were moved back to the listeners).
  Future<void> _onPermissions(ParticipantPermissionsUpdatedEvent event) async {
    if (event.participant is! LocalParticipant) {
      return;
    }
    final List<TrackSource> allowed = event.permissions.canPublishSources
        .map(_source)
        .whereType<TrackSource>()
        .toList();
    final bool canPublish = event.permissions.canPublish;

    if (!canPublish || !allowed.contains(TrackSource.microphone)) {
      micOn = false;
    }
    if (!canPublish || !allowed.contains(TrackSource.camera)) {
      cameraOn = false;
      await _room?.localParticipant
          ?.setCameraEnabled(false)
          .catchError((_) => null);
    }
    if (!canPublish || !allowed.contains(TrackSource.screenShareVideo)) {
      await _stopScreenShareLocally();
    }
    notifyListeners();
  }

  TrackSource? _source(Object source) {
    switch (source.toString()) {
      case 'MICROPHONE':
        return TrackSource.microphone;
      case 'CAMERA':
        return TrackSource.camera;
      case 'SCREEN_SHARE':
        return TrackSource.screenShareVideo;
      default:
        return null;
    }
  }

  // A host or co-host muted you.
  void _onMuted(TrackMutedEvent event) {
    if (event.participant is LocalParticipant &&
        event.publication.source == TrackSource.microphone) {
      micOn = false;
    }
    notifyListeners();
  }

  void _onLocalUnpublished(LocalTrackUnpublishedEvent event) {
    switch (event.publication.source) {
      case TrackSource.microphone:
        micOn = false;
      case TrackSource.camera:
        cameraOn = false;
      case TrackSource.screenShareVideo:
        sharingScreen = false;
      default:
        break;
    }
    notifyListeners();
  }

  //===================================================
  // REACTIONS — sent live, never stored
  //===================================================

  void _onData(DataReceivedEvent event) {
    if (event.topic != 'reaction') {
      return;
    }
    final String emoji = utf8.decode(event.data, allowMalformed: true);
    if (huddleReactionEmojis.contains(emoji)) {
      _reactions.add(HuddleReaction(emoji, event.participant?.name ?? ''));
    }
  }

  Future<void> sendReaction(String emoji) async {
    if (!huddleReactionEmojis.contains(emoji)) {
      return;
    }
    _reactions.add(HuddleReaction(emoji, 'You'));
    try {
      await _room?.localParticipant?.publishData(
        utf8.encode(emoji),
        reliable: false,
        topic: 'reaction',
      );
    } catch (_) {
      // A missed reaction is fine.
    }
  }

  //===================================================
  // MICROPHONE / CAMERA
  //
  // Permission is only asked for the first time you
  // actually turn the mic or camera on.
  //===================================================

  Future<String?> toggleMic() async {
    final LocalParticipant? me = _room?.localParticipant;
    if (me == null) {
      return 'You are not connected yet.';
    }

    final bool turnOn = !micOn;
    if (turnOn && !await Permission.microphone.request().isGranted) {
      return 'Allow microphone access in your phone settings to speak.';
    }

    try {
      await me.setMicrophoneEnabled(turnOn);
      micOn = turnOn;
      notifyListeners();
      return null;
    } catch (_) {
      return turnOn ? 'Could not turn on your microphone.' : null;
    }
  }

  Future<String?> toggleCamera() async {
    final LocalParticipant? me = _room?.localParticipant;
    if (me == null) {
      return 'You are not connected yet.';
    }

    final bool turnOn = !cameraOn;
    if (turnOn && !await Permission.camera.request().isGranted) {
      return 'Allow camera access in your phone settings to use video.';
    }

    try {
      await me.setCameraEnabled(
        turnOn,
        cameraCaptureOptions: CameraCaptureOptions(
          cameraPosition: _cameraPosition,
          params: VideoParametersPresets.h540_169,
        ),
      );
      cameraOn = turnOn;
      notifyListeners();
      return null;
    } catch (_) {
      return turnOn ? 'Could not turn on your camera.' : null;
    }
  }

  Future<void> flipCamera() async {
    final LocalTrackPublication? camera = _room?.localParticipant
        ?.getTrackPublicationBySource(TrackSource.camera);
    final Track? track = camera?.track;
    if (track is! LocalVideoTrack) {
      return;
    }

    _cameraPosition = _cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    try {
      await track.setCameraPosition(_cameraPosition);
    } catch (_) {}
  }

  //===================================================
  // SCREEN SHARING
  //
  // Your voice keeps working while you present. Only
  // one person presents at a time (the backend checks).
  // Android: the system asks for capture permission,
  // then Nubify shows a "sharing your screen"
  // notification while it is on.
  //===================================================

  Future<String?> startScreenShare() async {
    final String? id = huddleId;
    final LocalParticipant? me = _room?.localParticipant;
    if (id == null || me == null) {
      return 'You are not connected yet.';
    }

    try {
      await _service.action(id, 'claimScreenShare');
    } on HuddleException catch (error) {
      return error.message;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final bool allowed = await rtc.Helper.requestCapturePermission();
        if (!allowed) {
          await _release(id);
          return 'Screen sharing was not allowed.';
        }
        await _startForegroundService();
      }

      await me.setScreenShareEnabled(true, captureScreenAudio: false);
      sharingScreen = true;
      notifyListeners();
      return null;
    } catch (_) {
      await _stopScreenShareLocally();
      await _release(id);
      return 'Could not start screen sharing.';
    }
  }

  Future<void> stopScreenShare() async {
    await _stopScreenShareLocally();
    final String? id = huddleId;
    if (id != null) {
      await _release(id);
    }
  }

  Future<void> _release(String id) async {
    try {
      await _service.action(id, 'releaseScreenShare');
    } catch (_) {}
  }

  Future<void> _stopScreenShareLocally() async {
    if (sharingScreen) {
      try {
        await _room?.localParticipant?.setScreenShareEnabled(false);
      } catch (_) {}
    }
    sharingScreen = false;
    await _stopForegroundService();
    notifyListeners();
  }

  Future<void> _startForegroundService() async {
    final bool ready = await FlutterBackground.initialize(
      androidConfig: const FlutterBackgroundAndroidConfig(
        notificationTitle: 'Nubify is sharing your screen',
        notificationText: 'Everything on your screen is visible in the Huddle.',
        notificationImportance: AndroidNotificationImportance.normal,
        shouldRequestBatteryOptimizationsOff: false,
        notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
      ),
    );
    if (ready) {
      await FlutterBackground.enableBackgroundExecution();
    }
  }

  Future<void> _stopForegroundService() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (_) {}
  }

  //===================================================
  // LEAVING
  //===================================================

  // Stop speaking but stay in the Huddle as a listener.
  Future<String?> leaveAsSpeaker() async {
    final String? id = huddleId;
    if (id == null) {
      return null;
    }

    // Stop sending immediately, before the server replies.
    await _stopAllMedia();
    try {
      await _service.action(id, 'leaveAsSpeaker');
      return null;
    } on HuddleException catch (error) {
      return error.message;
    }
  }

  // Leave the Huddle completely.
  Future<void> leave() async {
    final String? id = huddleId;
    if (id == null) {
      return;
    }
    if (sharingScreen) {
      unawaited(_release(id));
    }
    unawaited(_service.action(id, 'leave').catchError((Object _) {}));
    await _teardown();
    connection = HuddleConnection.idle;
    huddleId = null;
    notifyListeners();
  }

  // Host only: closes the Huddle for everyone.
  Future<String?> end() async {
    final String? id = huddleId;
    if (id == null) {
      return null;
    }
    try {
      await _service.action(id, 'end');
    } on HuddleException catch (error) {
      if (!error.ended) {
        return error.message;
      }
    }
    await _teardown();
    connection = HuddleConnection.ended;
    endMessage = 'You ended the Huddle.';
    notifyListeners();
    return null;
  }

  // Clears the "ended" state after its screen is shown.
  void reset() {
    if (!isActive) {
      huddleId = null;
      connection = HuddleConnection.idle;
      endMessage = null;
      notifyListeners();
    }
  }

  Future<void> _stopAllMedia() async {
    final LocalParticipant? me = _room?.localParticipant;
    try {
      await me?.setMicrophoneEnabled(false);
      await me?.setCameraEnabled(false);
    } catch (_) {}
    micOn = false;
    cameraOn = false;
    await _stopScreenShareLocally();
  }

  Future<void> _teardown() async {
    final Room? room = _room;
    final EventsListener<RoomEvent>? events = _events;
    _room = null;
    _events = null;

    await _stopForegroundService();
    micOn = false;
    cameraOn = false;
    sharingScreen = false;
    speakingIds = <String>{};

    await events?.dispose();
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {}
      try {
        await room.dispose();
      } catch (_) {}
    }
  }
}