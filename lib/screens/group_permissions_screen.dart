import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_group.dart';
import '../services/group_chat_service.dart';

//===============================
// GROUP PERMISSIONS SCREEN
//===============================

class GroupPermissionsScreen
    extends StatelessWidget {
  GroupPermissionsScreen({
    super.key,
    required this.groupId,
  });

  final String groupId;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  final GroupChatService
  _groupService =
  GroupChatService();

  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

  //===============================
  // UPDATE
  //===============================

  Future<void> _update({
    required BuildContext context,
    required String permission,
    required bool value,
  }) async {
    try {
      await _groupService.updatePermission(
        groupId:
        groupId,
        permission:
        permission,
        value:
        value,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
          Text(
            error
                .toString()
                .replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    }
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
          'Group permissions',
          style:
          TextStyle(
            fontWeight:
            FontWeight.w800,
          ),
        ),
      ),
      body:
      StreamBuilder(
        stream:
        _groupService.groupStream(
          groupId,
        ),
        builder:
            (
            BuildContext context,
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
                'Group not found.',
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

          return ListView(
            children:
            <Widget>[
              const Padding(
                padding:
                EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  7,
                ),
                child:
                Text(
                  'Members can',
                  style:
                  TextStyle(
                    color:
                    _blue,
                    fontSize:
                    13,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),

              //===============================
              // EDIT GROUP SETTINGS
              //===============================

              SwitchListTile(
                value:
                group.permissions
                    .membersCanEditGroupSettings,
                onChanged:
                admin
                    ? (
                    bool value,
                    ) {
                  _update(
                    context:
                    context,
                    permission:
                    'membersCanEditGroupSettings',
                    value:
                    value,
                  );
                }
                    : null,
                activeThumbColor:
                _blue,
                secondary:
                const Icon(
                  Icons.edit_rounded,
                ),
                title:
                const Text(
                  'Edit group settings',
                ),
                subtitle:
                const Text(
                  'Change the group name, photo and description',
                ),
              ),

              //===============================
              // SEND MESSAGES
              //===============================

              SwitchListTile(
                value:
                group.permissions
                    .membersCanSendMessages,
                onChanged:
                admin
                    ? (
                    bool value,
                    ) {
                  _update(
                    context:
                    context,
                    permission:
                    'membersCanSendMessages',
                    value:
                    value,
                  );
                }
                    : null,
                activeThumbColor:
                _blue,
                secondary:
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                ),
                title:
                const Text(
                  'Send new messages',
                ),
                subtitle:
                const Text(
                  'When off, only admins can send messages',
                ),
              ),

              //===============================
              // ADD MEMBERS
              //===============================

              SwitchListTile(
                value:
                group.permissions
                    .membersCanAddMembers,
                onChanged:
                admin
                    ? (
                    bool value,
                    ) {
                  _update(
                    context:
                    context,
                    permission:
                    'membersCanAddMembers',
                    value:
                    value,
                  );
                }
                    : null,
                activeThumbColor:
                _blue,
                secondary:
                const Icon(
                  Icons.person_add_alt_1_rounded,
                ),
                title:
                const Text(
                  'Add other members',
                ),
                subtitle:
                Text(
                  group.permissions.membersCanAddMembers
                      ? 'Members can add other Nubify users'
                      : 'Only admins can add members',
                ),
              ),

              //===============================
              // MESSAGE HISTORY
              //===============================

              SwitchListTile(
                value:
                group.permissions
                    .newMembersCanSeeHistory,
                onChanged:
                admin
                    ? (
                    bool value,
                    ) {
                  _update(
                    context:
                    context,
                    permission:
                    'newMembersCanSeeHistory',
                    value:
                    value,
                  );
                }
                    : null,
                activeThumbColor:
                _blue,
                secondary:
                const Icon(
                  Icons.history_rounded,
                ),
                title:
                const Text(
                  'Send previous message history',
                ),
                subtitle:
                const Text(
                  'Allow new members to see messages sent before they joined',
                ),
              ),

              const Divider(
                height:
                30,
              ),

              const Padding(
                padding:
                EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  7,
                ),
                child:
                Text(
                  'Admins can',
                  style:
                  TextStyle(
                    color:
                    _blue,
                    fontSize:
                    13,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),

              //===============================
              // APPROVE NEW MEMBERS
              //===============================

              SwitchListTile(
                value:
                group.permissions
                    .adminApprovalRequired,
                onChanged:
                admin
                    ? (
                    bool value,
                    ) {
                  _update(
                    context:
                    context,
                    permission:
                    'adminApprovalRequired',
                    value:
                    value,
                  );
                }
                    : null,
                activeThumbColor:
                _blue,
                secondary:
                const Icon(
                  Icons
                      .admin_panel_settings_outlined,
                ),
                title:
                const Text(
                  'Approve new members',
                ),
                subtitle:
                const Text(
                  'People joining with the group link need admin approval',
                ),
              ),

              if (!admin)
                const Padding(
                  padding:
                  EdgeInsets.all(
                    18,
                  ),
                  child:
                  Text(
                    'Only group admins can change these permissions.',
                    style:
                    TextStyle(
                      color:
                      Colors.white54,
                    ),
                  ),
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