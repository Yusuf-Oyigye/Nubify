import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_group.dart';
import '../services/group_chat_service.dart';
import 'add_group_members_screen.dart';
import 'group_permissions_screen.dart';
import 'profile_screen.dart';
import 'chat_forward_screen.dart';
import '../services/chat_media_service.dart';
import '../widgets/full_photo_viewer.dart';
import 'group_join_requests_screen.dart';

//===============================
// GROUP INFO SCREEN
//===============================

class GroupInfoScreen
    extends StatefulWidget {
  const GroupInfoScreen({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<GroupInfoScreen>
  createState() =>
      _GroupInfoScreenState();
}

//===============================
// GROUP INFO STATE
//===============================

class _GroupInfoScreenState
    extends State<
        GroupInfoScreen> {
  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  final GroupChatService
  _groupService =
  GroupChatService();

  final ChatMediaService
  _mediaService =
  ChatMediaService();

  final ImagePicker
  _imagePicker =
  ImagePicker();

  bool _changingPhoto =
  false;

  //===============================
// CHANGE GROUP PHOTO
//===============================

  Future<void> _changeGroupPhoto(
      ChatGroup group,
      ) async {
    final String uid =
        _auth.currentUser?.uid ??
            '';

    if (!group.isAdmin(
      uid,
    )) {
      return;
    }

    final XFile? image =
    await _imagePicker
        .pickImage(
      source:
      ImageSource.gallery,

      imageQuality:
      90,
    );

    if (image == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _changingPhoto =
        true;
      });
    }

    try {
      final String url =
      await _mediaService
          .uploadGroupPhoto(
        groupId:
        group.groupId,

        filePath:
        image.path,
      );

      await _groupService
          .updateGroupInfo(
        groupId:
        group.groupId,

        photoUrl:
        url,
      );
    } catch (error) {
      _message(
        error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingPhoto =
          false;
        });
      }
    }
  }
  //===============================
// EDIT NAME
//===============================

  Future<void> _editName(
      ChatGroup group,
      ) async {
    String draft =
        group.name;

    final String? value =
    await showDialog<String>(
      context:
      context,

      builder:
          (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Edit group name',
          ),

          content:
          TextFormField(
            initialValue:
            group.name,

            autofocus:
            true,

            maxLength:
            80,

            onChanged:
                (
                String value,
                ) {
              draft =
                  value;
            },
          ),

          actions:
          <Widget>[
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
              const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  draft.trim(),
                );
              },

              child:
              const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    if (value == null ||
        value.trim().isEmpty) {
      return;
    }

    try {
      await _groupService
          .updateGroupInfo(
        groupId:
        group.groupId,

        name:
        value.trim(),
      );
    } catch (error) {
      _message(
        error.toString(),
      );
    }
  }

  //===============================
// EDIT DESCRIPTION
//===============================

  Future<void> _editDescription(
      ChatGroup group,
      ) async {
    String draft =
        group.description;

    final String? value =
    await showDialog<String>(
      context:
      context,

      builder:
          (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Edit description',
          ),

          content:
          TextFormField(
            initialValue:
            group.description,

            autofocus:
            true,

            maxLength:
            300,

            maxLines:
            5,

            onChanged:
                (
                String value,
                ) {
              draft =
                  value;
            },
          ),

          actions:
          <Widget>[
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
              const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  draft.trim(),
                );
              },

              child:
              const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    if (value == null) {
      return;
    }

    try {
      await _groupService
          .updateGroupInfo(
        groupId:
        group.groupId,

        description:
        value.trim(),
      );
    } catch (error) {
      _message(
        error.toString(),
      );
    }
  }
  //===============================
  // INVITE LINK
  //===============================

  Future<String?> _inviteLink() async {
    try {
      return await _groupService.getInviteLink(
        widget.groupId,
      );
    } catch (error) {
      _message(
        error.toString(),
      );

      return null;
    }
  }

  //===============================
  // COPY LINK
  //===============================

  Future<void> _copyLink() async {
    final String? link =
    await _inviteLink();

    if (link == null) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text:
        link,
      ),
    );

    _message(
      'Group link copied.',
    );
  }

  //===============================
  // SHARE LINK
  //===============================

  Future<void> _shareLink() async {
    final String? link =
    await _inviteLink();

    if (link == null) {
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text:
        link,
        title:
        'Join my Nubify group',
      ),
    );
  }
  //===============================
// FORWARD GROUP LINK
//===============================

  Future<void> _forwardLink() async {
    final String? link =
    await _inviteLink();

    if (link == null ||
        !mounted) {
      return;
    }

    Navigator.push(
      context,

      MaterialPageRoute<void>(
        builder:
            (_) =>
            ChatForwardScreen(
              text:
              link,
            ),
      ),
    );
  }

  //===============================
  // QR CODE
  //===============================

  Future<void> _showQr() async {
    final String? link =
    await _inviteLink();

    if (link == null ||
        !mounted) {
      return;
    }

    await showDialog<void>(
      context:
      context,
      builder:
          (
          BuildContext context,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Group QR code',
          ),
          content:
          SizedBox(
            width:
            250,
            height:
            250,
            child:
            Center(
              child:
              Container(
                color:
                Colors.white,
                padding:
                const EdgeInsets.all(
                  12,
                ),
                child:
                QrImageView(
                  data:
                  link,
                  size:
                  210,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  //===============================
  // RESET LINK
  //===============================

  Future<void> _resetLink() async {
    final bool? confirm =
    await showDialog<bool>(
      context:
      context,
      builder:
          (
          BuildContext context,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Reset group link?',
          ),
          content:
          const Text(
            'The old invite link will stop working.',
          ),
          actions:
          <Widget>[
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
              const Text(
                'Reset',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await _groupService.resetInviteLink(
        widget.groupId,
      );

      _message(
        'New group link created.',
      );
    } catch (error) {
      _message(
        error.toString(),
      );
    }
  }

  //===============================
  // MEMBER OPTIONS
  //===============================

  Future<void> _memberOptions({
    required ChatGroup group,
    required String memberId,
    required String memberName,
  }) async {
    final String uid =
        _auth.currentUser?.uid ??
            '';

    if (!group.isAdmin(
      uid,
    )) {
      return;
    }

    if (memberId ==
        uid) {
      return;
    }

    await showModalBottomSheet<void>(
      context:
      context,
      showDragHandle:
      true,
      builder:
          (
          BuildContext context,
          ) {
        final bool memberAdmin =
        group.isAdmin(
          memberId,
        );

        return SafeArea(
          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,
            children:
            <Widget>[
              ListTile(
                leading:
                const Icon(
                  Icons.person_outline_rounded,
                ),
                title:
                const Text(
                  'View profile',
                ),
                onTap:
                    () {
                  Navigator.pop(
                    context,
                  );

                  Navigator.push(
                    this.context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                          ProfileScreen(
                            uid:
                            memberId,
                          ),
                    ),
                  );
                },
              ),

              if (!memberAdmin)
                ListTile(
                  leading:
                  const Icon(
                    Icons
                        .admin_panel_settings_outlined,
                  ),
                  title:
                  const Text(
                    'Make group admin',
                  ),
                  onTap:
                      () async {
                    Navigator.pop(
                      context,
                    );

                    await _groupService.makeAdmin(
                      groupId:
                      group.groupId,
                      userId:
                      memberId,
                    );
                  },
                ),

              if (memberAdmin &&
                  memberId !=
                      group.creatorId)
                ListTile(
                  leading:
                  const Icon(
                    Icons
                        .remove_moderator_outlined,
                  ),
                  title:
                  const Text(
                    'Dismiss as admin',
                  ),
                  onTap:
                      () async {
                    Navigator.pop(
                      context,
                    );

                    await _groupService.dismissAdmin(
                      groupId:
                      group.groupId,
                      userId:
                      memberId,
                    );
                  },
                ),

              if (memberId !=
                  group.creatorId)
                ListTile(
                  leading:
                  const Icon(
                    Icons.person_remove_alt_1_rounded,
                    color:
                    Colors.redAccent,
                  ),
                  title:
                  Text(
                    'Remove $memberName',
                    style:
                    const TextStyle(
                      color:
                      Colors.redAccent,
                    ),
                  ),
                  onTap:
                      () async {
                    Navigator.pop(
                      context,
                    );

                    await _groupService.removeMember(
                      groupId:
                      group.groupId,
                      userId:
                      memberId,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  //===============================
// LEAVE GROUP
//===============================

  Future<void> _leaveGroup() async {
    final bool? confirm =
    await showDialog<bool>(
      context:
      context,

      builder:
          (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Exit group?',
          ),

          content:
          const Text(
            'Are you sure you want to exit from the group?',
          ),

          actions:
          <Widget>[
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
              const Text(
                'No',
              ),
            ),

            FilledButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
              const Text(
                'Yes',
              ),
            ),
          ],
        );
      },
    );

    if (confirm !=
        true) {
      return;
    }

    try {
      await _groupService
          .leaveGroup(
        widget.groupId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).popUntil(
            (
            Route<dynamic> route,
            ) =>
        route.isFirst,
      );
    } catch (error) {
      _message(
        error.toString(),
      );
    }
  }

  //===============================
  // MESSAGE
  //===============================

  void _message(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(
          message.replaceFirst(
            'Exception: ',
            '',
          ),
        ),
      ),
    );
  }

  //===============================
  // MEMBER TILE
  //===============================

  Widget _memberTile({
    required ChatGroup group,
    required String memberId,
  }) {
    return FutureBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      future:
      _firestore
          .collection(
        'users',
      )
          .doc(
        memberId,
      )
          .get(),
      builder:
          (
          BuildContext context,
          AsyncSnapshot<
              DocumentSnapshot<
                  Map<String, dynamic>>>
          snapshot,
          ) {
        final Map<String, dynamic>
        user =
            snapshot.data?.data() ??
                <String, dynamic>{};

        final String fullName =
        (user['fullName'] ?? '')
            .toString();

        final String username =
        (user['username'] ?? '')
            .toString();

        final String photoUrl =
        (user['photoUrl'] ?? '')
            .toString();

        final String name =
        fullName.trim().isNotEmpty
            ? fullName
            : username.trim().isNotEmpty
            ? username
            : 'Nubify user';

        final bool admin =
        group.isAdmin(
          memberId,
        );

        return ListTile(
          onTap:
              () {
            _memberOptions(
              group:
              group,
              memberId:
              memberId,
              memberName:
              name,
            );
          },
          leading:
          CircleAvatar(
            radius:
            23,
            backgroundImage:
            photoUrl.trim().isNotEmpty
                ? NetworkImage(
              photoUrl,
            )
                : null,
            child:
            photoUrl.trim().isEmpty
                ? const Icon(
              Icons.person_rounded,
            )
                : null,
          ),
          title:
          Text(
            name,
            style:
            const TextStyle(
              color:
              Colors.white,
              fontWeight:
              FontWeight.w700,
            ),
          ),
          subtitle:
          username.trim().isNotEmpty
              ? Text(
            '@$username',
            style:
            const TextStyle(
              color:
              Colors.white54,
            ),
          )
              : null,
          trailing:
          admin
              ? Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal:
              8,
              vertical:
              4,
            ),
            decoration:
            BoxDecoration(
              color:
              _blue.withValues(
                alpha: 0.12,
              ),
              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),
            child:
            const Text(
              'Admin',
              style:
              TextStyle(
                color:
                _blue,
                fontSize:
                10,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          )
              : null,
        );
      },
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(
        0xFF0B1116,
      ),
      appBar:
      AppBar(
        backgroundColor:
        const Color(
          0xFF0B1116,
        ),
        title:
        const Text(
          'Group info',
          style:
          TextStyle(
            fontWeight:
            FontWeight.w800,
          ),
        ),
      ),
      body:
      StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream:
        _groupService.groupStream(
          widget.groupId,
        ),
        builder:
            (
            BuildContext context,
            AsyncSnapshot<
                DocumentSnapshot<
                    Map<String, dynamic>>>
            snapshot,
            ) {
          if (!snapshot.hasData) {
            return const Center(
              child:
              CircularProgressIndicator(
                color:
                _blue,
              ),
            );
          }

          if (!snapshot.data!.exists) {
            return const Center(
              child:
              Text(
                'Group no longer exists.',
              ),
            );
          }

          final ChatGroup group =
          ChatGroup.fromDocument(
            snapshot.data!,
          );

          final String uid =
              _auth.currentUser?.uid ??
                  '';

          final bool admin =
          group.isAdmin(
            uid,
          );

          final bool canEdit =
              admin ||
                  group.permissions
                      .membersCanEditGroupSettings;

          final bool canAdd =
              admin ||
                  group.permissions
                      .membersCanAddMembers;

          return ListView(
            children:
            <Widget>[
              //===============================
              // GROUP HEADER
              //===============================

              Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  24,
                ),
                child:
                Column(
                  children:
                  <Widget>[
                    Stack(
                      clipBehavior:
                      Clip.none,

                      children:
                      <Widget>[
                        GestureDetector(
                          onTap:
                              () {
                            Navigator.push(
                              context,

                              MaterialPageRoute<void>(
                                builder:
                                    (_) =>
                                    FullPhotoViewer(
                                      title:
                                      group.name,

                                      photoUrl:
                                      group.photoUrl,

                                      group:
                                      true,
                                    ),
                              ),
                            );
                          },

                          child:
                          CircleAvatar(
                            radius:
                            52,

                            backgroundColor:
                            const Color(
                              0xFF17252E,
                            ),

                            backgroundImage:
                            group.photoUrl
                                .trim()
                                .isNotEmpty
                                ? NetworkImage(
                              group.photoUrl,
                            )
                                : null,

                            child:
                            group.photoUrl
                                .trim()
                                .isEmpty
                                ? const Icon(
                              Icons.groups_rounded,

                              color:
                              _blue,

                              size:
                              48,
                            )
                                : null,
                          ),
                        ),

                        if (admin)
                          Positioned(
                            right:
                            -3,

                            bottom:
                            -3,

                            child:
                            GestureDetector(
                              onTap:
                              _changingPhoto
                                  ? null
                                  : () {
                                _changeGroupPhoto(
                                  group,
                                );
                              },

                              child:
                              CircleAvatar(
                                radius:
                                18,

                                backgroundColor:
                                _blue,

                                child:
                                _changingPhoto
                                    ? const SizedBox(
                                  width:
                                  17,

                                  height:
                                  17,

                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth:
                                    2,

                                    color:
                                    Colors.white,
                                  ),
                                )
                                    : const Icon(
                                  Icons.camera_alt_rounded,

                                  color:
                                  Colors.white,

                                  size:
                                  18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height:
                      13,
                    ),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children:
                      <Widget>[
                        Flexible(
                          child:
                          Text(
                            group.name,
                            textAlign:
                            TextAlign.center,
                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                              fontSize:
                              23,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),

                        if (canEdit)
                          IconButton(
                            onPressed:
                                () {
                              _editName(
                                group,
                              );
                            },
                            icon:
                            const Icon(
                              Icons.edit_rounded,
                              color:
                              _blue,
                              size:
                              19,
                            ),
                          ),
                      ],
                    ),

                    Text(
                      '${group.memberIds.length} members',
                      style:
                      const TextStyle(
                        color:
                        Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),

              //===============================
              // DESCRIPTION
              //===============================

              ListTile(
                leading:
                const Icon(
                  Icons.info_outline_rounded,
                ),
                title:
                const Text(
                  'Description',
                ),
                subtitle:
                Text(
                  group.description.trim().isNotEmpty
                      ? group.description
                      : 'No group description',
                  style:
                  const TextStyle(
                    color:
                    Colors.white60,
                  ),
                ),
                trailing:
                canEdit
                    ? IconButton(
                  onPressed:
                      () {
                    _editDescription(
                      group,
                    );
                  },
                  icon:
                  const Icon(
                    Icons.edit_rounded,
                    size:
                    19,
                  ),
                )
                    : null,
              ),

              const Divider(),

              //===============================
              // ADD MEMBERS
              //===============================

              if (canAdd)
                ListTile(
                  leading:
                  const CircleAvatar(
                    backgroundColor:
                    Color(
                      0xFF173C4D,
                    ),
                    child:
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      color:
                      _blue,
                    ),
                  ),
                  title:
                  const Text(
                    'Add members',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  onTap:
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) =>
                            AddGroupMembersScreen(
                              groupId:
                              group.groupId,
                            ),
                      ),
                    );
                  },
                ),

              //===============================
              // GROUP PERMISSIONS
              //===============================

              if (admin)
                ListTile(
                  leading:
                  const CircleAvatar(
                    backgroundColor:
                    Color(
                      0xFF173C4D,
                    ),
                    child:
                    Icon(
                      Icons
                          .admin_panel_settings_outlined,
                      color:
                      _blue,
                    ),
                  ),
                  title:
                  const Text(
                    'Group permissions',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  subtitle:
                  const Text(
                    'Control what members can do',
                  ),
                  onTap:
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) =>
                            GroupPermissionsScreen(
                              groupId:
                              group.groupId,
                            ),

                      ),
                    );
                  },
                ),
              //===================================================
// ADMIN JOIN REQUESTS
//===================================================

              if (admin)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF173C4D),
                    child: Icon(
                      Icons.how_to_reg_rounded,
                      color: _blue,
                    ),
                  ),
                  title: const Text(
                    'Join requests',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Approve or reject students',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupJoinRequestsScreen(
                          groupId: group.groupId,
                        ),
                      ),
                    );
                  },
                ),

              const Divider(),

              //===============================
              // INVITE LINK
              //===============================

              const Padding(
                padding:
                EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  5,
                ),
                child:
                Text(
                  'Invite to group',
                  style:
                  TextStyle(
                    color:
                    _blue,
                    fontWeight:
                    FontWeight.w800,
                    fontSize:
                    13,
                  ),
                ),
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.share_rounded,
                ),
                title:
                const Text(
                  'Share group link',
                ),
                onTap:
                _shareLink,
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.forward_rounded,
                ),
                title:
                const Text(
                  'Forward group link',
                ),
                onTap:
                _forwardLink,
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.content_copy_rounded,
                ),
                title:
                const Text(
                  'Copy group link',
                ),
                onTap:
                _copyLink,
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.qr_code_2_rounded,
                ),
                title:
                const Text(
                  'QR code',
                ),
                onTap:
                _showQr,
              ),

              if (admin)
                ListTile(
                  leading:
                  const Icon(
                    Icons.refresh_rounded,
                    color:
                    Colors.orange,
                  ),
                  title:
                  const Text(
                    'Reset group link',
                  ),
                  subtitle:
                  const Text(
                    'Old link will stop working',
                  ),
                  onTap:
                  _resetLink,
                ),

              const Divider(),

              //===============================
              // MEMBERS
              //===============================

              Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  5,
                ),
                child:
                Text(
                  '${group.memberIds.length} members',
                  style:
                  const TextStyle(
                    color:
                    _blue,
                    fontWeight:
                    FontWeight.w800,
                    fontSize:
                    13,
                  ),
                ),
              ),

              ...group.memberIds.map(
                    (
                    String memberId,
                    ) =>
                    _memberTile(
                      group:
                      group,
                      memberId:
                      memberId,
                    ),
              ),

              const Divider(
                height:
                35,
              ),

              //===============================
              // EXIT GROUP
              //===============================

              ListTile(
                leading:
                const Icon(
                  Icons.exit_to_app_rounded,
                  color:
                  Colors.redAccent,
                ),
                title:
                const Text(
                  'Exit group',
                  style:
                  TextStyle(
                    color:
                    Colors.redAccent,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                onTap:
                _leaveGroup,
              ),

              const SizedBox(
                height:
                30,
              ),
            ],
          );
        },
      ),
    );
  }
}