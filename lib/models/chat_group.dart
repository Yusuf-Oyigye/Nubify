import 'package:cloud_firestore/cloud_firestore.dart';

//===============================
// GROUP PERMISSIONS
//===============================

class ChatGroupPermissions {
  final bool membersCanEditGroupSettings;
  final bool membersCanSendMessages;
  final bool membersCanAddMembers;
  final bool newMembersCanSeeHistory;
  final bool adminApprovalRequired;

  const ChatGroupPermissions({
    this.membersCanEditGroupSettings = false,
    this.membersCanSendMessages = true,
    this.membersCanAddMembers = false,
    this.newMembersCanSeeHistory = true,
    this.adminApprovalRequired = false,
  });

  //===============================
  // FROM MAP
  //===============================

  factory ChatGroupPermissions.fromMap(
      dynamic value,
      ) {
    final Map<String, dynamic> map =
    value is Map
        ? Map<String, dynamic>.from(
      value,
    )
        : <String, dynamic>{};

    return ChatGroupPermissions(
      membersCanEditGroupSettings:
      map['membersCanEditGroupSettings'] ==
          true,

      membersCanSendMessages:
      map['membersCanSendMessages'] !=
          false,

      membersCanAddMembers:
      map['membersCanAddMembers'] ==
          true,

      newMembersCanSeeHistory:
      map['newMembersCanSeeHistory'] !=
          false,

      adminApprovalRequired:
      map['adminApprovalRequired'] ==
          true,
    );
  }

  //===============================
  // TO MAP
  //===============================

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'membersCanEditGroupSettings':
      membersCanEditGroupSettings,

      'membersCanSendMessages':
      membersCanSendMessages,

      'membersCanAddMembers':
      membersCanAddMembers,

      'newMembersCanSeeHistory':
      newMembersCanSeeHistory,

      'adminApprovalRequired':
      adminApprovalRequired,
    };
  }
}

//===============================
// CHAT GROUP MODEL
//===============================

class ChatGroup {
  final String groupId;

  final String name;
  final String description;
  final String photoUrl;

  final String creatorId;

  final List<String> memberIds;
  final List<String> adminIds;

  final ChatGroupPermissions permissions;

  final String inviteToken;

  final String lastMessage;
  final String lastMessageType;
  final String lastMessageSenderId;

  final Timestamp? lastMessageAt;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  final Map<String, Timestamp>
  memberJoinedAt;

  const ChatGroup({
    required this.groupId,
    required this.name,
    required this.description,
    required this.photoUrl,
    required this.creatorId,
    required this.memberIds,
    required this.adminIds,
    required this.permissions,
    required this.inviteToken,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    required this.memberJoinedAt,
  });

  //===============================
  // FROM DOCUMENT
  //===============================

  factory ChatGroup.fromDocument(
      DocumentSnapshot<Map<String, dynamic>>
      document,
      ) {
    final Map<String, dynamic> data =
        document.data() ??
            <String, dynamic>{};

    return ChatGroup(
      groupId: (
          data['groupId'] ??
              document.id
      )
          .toString(),

      name: (
          data['name'] ??
              'Group'
      )
          .toString(),

      description: (
          data['description'] ??
              ''
      )
          .toString(),

      photoUrl: (
          data['photoUrl'] ??
              ''
      )
          .toString(),

      creatorId: (
          data['creatorId'] ??
              ''
      )
          .toString(),

      memberIds:
      _stringList(
        data['memberIds'] ??
            data['members'],
      ),

      adminIds:
      _stringList(
        data['adminIds'],
      ),

      permissions:
      ChatGroupPermissions.fromMap(
        data['permissions'],
      ),

      inviteToken: (
          data['inviteToken'] ??
              ''
      )
          .toString(),

      lastMessage: (
          data['lastMessage'] ??
              ''
      )
          .toString(),

      lastMessageType: (
          data['lastMessageType'] ??
              ''
      )
          .toString(),

      lastMessageSenderId: (
          data['lastMessageSenderId'] ??
              data['lastSenderId'] ??
              ''
      )
          .toString(),

      lastMessageAt:
      data['lastMessageAt']
      is Timestamp
          ? data['lastMessageAt']
      as Timestamp
          : null,

      createdAt:
      data['createdAt']
      is Timestamp
          ? data['createdAt']
      as Timestamp
          : null,

      updatedAt:
      data['updatedAt']
      is Timestamp
          ? data['updatedAt']
      as Timestamp
          : null,

      memberJoinedAt:
      _timestampMap(
        data['memberJoinedAt'],
      ),
    );
  }

  //===============================
  // MEMBER
  //===============================

  bool isMember(
      String uid,
      ) {
    return memberIds.contains(
      uid,
    );
  }

  //===============================
  // ADMIN
  //===============================

  bool isAdmin(
      String uid,
      ) {
    return adminIds.contains(
      uid,
    );
  }

  //===============================
  // STRING LIST
  //===============================

  static List<String> _stringList(
      dynamic value,
      ) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map(
          (dynamic item) =>
          item.toString(),
    )
        .where(
          (String item) =>
      item.trim().isNotEmpty,
    )
        .toList();
  }

  //===============================
  // TIMESTAMP MAP
  //===============================

  static Map<String, Timestamp>
  _timestampMap(
      dynamic value,
      ) {
    if (value is! Map) {
      return <String, Timestamp>{};
    }

    final Map<String, Timestamp>
    result =
    <String, Timestamp>{};

    value.forEach(
          (
          dynamic key,
          dynamic item,
          ) {
        if (item is Timestamp) {
          result[key.toString()] =
              item;
        }
      },
    );

    return result;
  }
}