import 'package:cloud_firestore/cloud_firestore.dart';

//===================================================
// NUB HUDDLES — DATA MODELS
//
// These only describe what Firestore stores. The live
// audio, video and screen sharing go through LiveKit.
//===================================================

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;

String _text(Object? value) => (value ?? '').toString();

//===================================================
// ROLES
//===================================================

enum HuddleRole {
  host('host', 'Host'),
  coHost('cohost', 'Co-host'),
  speaker('speaker', 'Speaker'),
  listener('listener', 'Listener');

  const HuddleRole(this.value, this.label);

  final String value;
  final String label;

  bool get canSpeak => this != listener;
  bool get canManage => this == host || this == coHost;

  static HuddleRole from(Object? value) => HuddleRole.values.firstWhere(
        (role) => role.value == value,
    orElse: () => HuddleRole.listener,
  );
}

//===================================================
// WHO CAN JOIN
//===================================================

enum HuddlePrivacy {
  everyone('everyone', 'Everyone on Nubify'),
  followers('followers', 'Followers & following'),
  inviteOnly('invite', 'Invite only');

  const HuddlePrivacy(this.value, this.label);

  final String value;
  final String label;

  static HuddlePrivacy from(Object? value) => HuddlePrivacy.values.firstWhere(
        (privacy) => privacy.value == value,
    orElse: () => HuddlePrivacy.everyone,
  );
}

//===================================================
// HUDDLE
//===================================================

class Huddle {
  const Huddle({
    required this.id,
    required this.title,
    required this.description,
    required this.topic,
    required this.mode,
    required this.privacy,
    required this.status,
    required this.hostId,
    required this.hostName,
    required this.hostPhotoUrl,
    required this.coHostIds,
    required this.allowSpeakerRequests,
    required this.allowVideo,
    required this.allowScreenShare,
    required this.chatEnabled,
    required this.participantCount,
    required this.speakerCount,
    required this.peakParticipants,
    required this.previewPhotos,
    required this.screenSharerId,
    required this.screenSharerName,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  factory Huddle.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

    return Huddle(
      id: doc.id,
      title: _text(data['title']),
      description: _text(data['description']),
      topic: _text(data['topic']),
      mode: _text(data['mode']),
      privacy: HuddlePrivacy.from(data['privacy']),
      status: _text(data['status']),
      hostId: _text(data['hostId']),
      hostName: _text(data['hostName']),
      hostPhotoUrl: _text(data['hostPhotoUrl']),
      coHostIds: List<String>.from(data['coHostIds'] ?? const <String>[]),
      allowSpeakerRequests: data['allowSpeakerRequests'] != false,
      allowVideo: data['allowVideo'] != false,
      allowScreenShare: data['allowScreenShare'] != false,
      chatEnabled: data['chatEnabled'] != false,
      participantCount: (data['participantCount'] as num?)?.toInt() ?? 0,
      speakerCount: (data['speakerCount'] as num?)?.toInt() ?? 0,
      peakParticipants: (data['peakParticipants'] as num?)?.toInt() ?? 0,
      previewPhotos: List<String>.from(
        data['previewPhotos'] ?? const <String>[],
      ),
      screenSharerId: _text(data['screenSharerId']),
      screenSharerName: _text(data['screenSharerName']),
      startedAt: _date(data['startedAt']),
      endedAt: _date(data['endedAt']),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String topic;
  final String mode;
  final HuddlePrivacy privacy;
  final String status;
  final String hostId;
  final String hostName;
  final String hostPhotoUrl;
  final List<String> coHostIds;
  final bool allowSpeakerRequests;
  final bool allowVideo;
  final bool allowScreenShare;
  final bool chatEnabled;
  final int participantCount;
  final int speakerCount;
  final int peakParticipants;
  final List<String> previewPhotos;
  final String screenSharerId;
  final String screenSharerName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  bool get isLive => status == 'live';

  int get listenerCount =>
      (participantCount - speakerCount).clamp(0, participantCount);

  // How long it has been live (or how long it lasted).
  Duration get elapsed {
    if (durationSeconds != null) {
      return Duration(seconds: durationSeconds!);
    }
    if (startedAt == null) {
      return Duration.zero;
    }
    final DateTime end = endedAt ?? DateTime.now();
    final Duration value = end.difference(startedAt!);
    return value.isNegative ? Duration.zero : value;
  }

  String get link => 'https://nubify.app/huddle/$id';
}

//===================================================
// PARTICIPANT
//===================================================

class HuddleParticipant {
  const HuddleParticipant({
    required this.uid,
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.role,
    required this.handRaisedAt,
    required this.speakerInviteBy,
    required this.speakerInviteByName,
    required this.joinedAt,
  });

  factory HuddleParticipant.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

    return HuddleParticipant(
      uid: doc.id,
      name: _text(data['name']),
      username: _text(data['username']),
      photoUrl: _text(data['photoUrl']),
      role: HuddleRole.from(data['role']),
      handRaisedAt: _date(data['handRaisedAt']),
      speakerInviteBy: _text(data['speakerInviteBy']),
      speakerInviteByName: _text(data['speakerInviteByName']),
      joinedAt: _date(data['joinedAt']),
    );
  }

  final String uid;
  final String name;
  final String username;
  final String photoUrl;
  final HuddleRole role;
  final DateTime? handRaisedAt;
  final String speakerInviteBy;
  final String speakerInviteByName;
  final DateTime? joinedAt;

  bool get handRaised => handRaisedAt != null;
  bool get hasSpeakerInvite => speakerInviteBy.isNotEmpty;

  // Host first, then co-hosts, speakers and listeners;
  // earliest arrivals first inside each group.
  static int compare(HuddleParticipant a, HuddleParticipant b) {
    final int byRole = a.role.index.compareTo(b.role.index);
    if (byRole != 0) {
      return byRole;
    }
    final DateTime far = DateTime(2100);
    return (a.joinedAt ?? far).compareTo(b.joinedAt ?? far);
  }
}

//===================================================
// CHAT MESSAGE (belongs only to this Huddle)
//===================================================

class HuddleChatMessage {
  const HuddleChatMessage({
    required this.id,
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.text,
    required this.replyToName,
    required this.replyToText,
    required this.createdAt,
  });

  factory HuddleChatMessage.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

    return HuddleChatMessage(
      id: doc.id,
      uid: _text(data['uid']),
      name: _text(data['name']),
      photoUrl: _text(data['photoUrl']),
      text: _text(data['text']),
      replyToName: _text(data['replyToName']),
      replyToText: _text(data['replyToText']),
      createdAt: _date(data['createdAt']),
    );
  }

  final String id;
  final String uid;
  final String name;
  final String photoUrl;
  final String text;
  final String replyToName;
  final String replyToText;
  final DateTime? createdAt;
}

//===================================================
// JOIN TICKET (what the server gives back on join)
//===================================================

class HuddleTicket {
  const HuddleTicket({
    required this.huddleId,
    required this.url,
    required this.token,
    required this.role,
  });

  factory HuddleTicket.fromMap(Map<String, dynamic> data) => HuddleTicket(
    huddleId: _text(data['huddleId']),
    url: _text(data['url']),
    token: _text(data['token']),
    role: HuddleRole.from(data['role']),
  );

  final String huddleId;
  final String url;
  final String token;
  final HuddleRole role;
}