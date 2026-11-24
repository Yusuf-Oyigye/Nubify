import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/chat/chat_group.dart';
import '../../../services/chat/group_chat_service.dart';
import '../../../l10n/nubify_text.dart';

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
        Text(context.tr('Group permissions'),
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
            return Center(
              child:
              Text(context.tr('Group not found.'),
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
              Padding(
                padding:
                EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  7,
                ),
                child:
                Text(context.tr('Members can'),
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
                Text(context.tr('Edit group settings'),
                ),
                subtitle:
                Text(context.tr('Change the group name, photo and description'),
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
                Text(context.tr('Send new messages'),
                ),
                subtitle:
                Text(context.tr('When off, only admins can send messages'),
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
                Text(context.tr('Add other members'),
                ),
                subtitle:
                Text(
                  group.permissions.membersCanAddMembers
                      ? context.tr('Members can add other Nubify users')
                      : context.tr('Only admins can add members'),
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
                Text(context.tr('Send previous message history'),
                ),
                subtitle:
                Text(context.tr('Allow new members to see messages sent before they joined'),
                ),
              ),

              const Divider(
                height:
                30,
              ),

              Padding(
                padding:
                EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  7,
                ),
                child:
                Text(context.tr('Admins can'),
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
                Text(context.tr('Approve new members'),
                ),
                subtitle:
                Text(context.tr('People joining with the group link need admin approval'),
                ),
              ),

              if (!admin)
                Padding(
                  padding:
                  EdgeInsets.all(
                    18,
                  ),
                  child:
                  Text(context.tr('Only group admins can change these permissions.'),
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