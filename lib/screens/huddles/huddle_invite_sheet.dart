import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/chat/chat_group.dart';
import '../../models/huddles/huddle.dart';
import '../../services/chat/group_chat_service.dart';
import '../../services/huddles/huddle_service.dart';
import '../../widgets/huddles/huddle_ui.dart';

//===================================================
// NUB HUDDLES — INVITE / SHARE
//
// Anyone in the Huddle can invite people. An invite
// always brings them in as a listener.
//===================================================

class HuddleInviteSheet {
  static Future<void> show(BuildContext context, {required Huddle huddle}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: HuddleColors.stageSoft,
      showDragHandle: true,
      builder: (sheetContext) {
        void close() => Navigator.pop(sheetContext);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  huddle.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _option(
                Icons.person_add_alt_1_rounded,
                'Invite Nubify people & groups',
                    () {
                  close();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _InvitePicker(huddle: huddle),
                    ),
                  );
                },
              ),
              _option(Icons.link_rounded, 'Copy Huddle link', () async {
                close();
                await Clipboard.setData(ClipboardData(text: huddle.link));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Huddle link copied')),
                  );
                }
              }),
              _option(Icons.ios_share_rounded, 'Share to other apps', () async {
                close();
                await SharePlus.instance.share(
                  ShareParams(text: HuddleService.instance.inviteText(huddle)),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  static Widget _option(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: HuddleColors.sky.withValues(alpha: .15),
        child: Icon(icon, color: HuddleColors.sky),
      ),
      title: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}

//===================================================
// PICK PEOPLE AND GROUPS
//===================================================

class _InvitePicker extends StatefulWidget {
  const _InvitePicker({required this.huddle});

  final Huddle huddle;

  @override
  State<_InvitePicker> createState() => _InvitePickerState();
}

class _InvitePickerState extends State<_InvitePicker> {
  final HuddleService _service = HuddleService.instance;
  final Set<String> _users = <String>{};
  final Set<String> _groups = <String>{};

  late final Future<QuerySnapshot<Map<String, dynamic>>> _people =
  FirebaseFirestore.instance.collection('users').limit(400).get();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _myGroups =
  GroupChatService().getGroups();

  String _search = '';
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int count = _users.length + _groups.length;

    try {
      await _service.invitePeople(
        widget.huddle,
        userIds: _users.toList(),
        groupIds: _groups.toList(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Invitation sent to $count ${count == 1 ? 'chat' : 'chats'}',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Some invitations could not be sent.')),
      );
    }
  }

  bool _matches(String text) =>
      _search.isEmpty || text.toLowerCase().contains(_search);

  @override
  Widget build(BuildContext context) {
    final int selected = _users.length + _groups.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite to Huddle'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search people and groups',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: selected == 0
          ? null
          : FloatingActionButton.extended(
        backgroundColor: HuddleColors.sky,
        foregroundColor: HuddleColors.stage,
        onPressed: _sending ? null : _send,
        icon: _sending
            ? const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.send_rounded),
        label: Text('Send ($selected)'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _myGroups,
            builder: (context, snapshot) {
              final List<ChatGroup> groups = (snapshot.data?.docs ?? const [])
                  .map(ChatGroup.fromDocument)
                  .where((group) => _matches(group.name))
                  .toList();
              if (groups.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Your groups'),
                  for (final ChatGroup group in groups)
                    CheckboxListTile(
                      value: _groups.contains(group.groupId),
                      onChanged: (on) => setState(
                            () => on == true
                            ? _groups.add(group.groupId)
                            : _groups.remove(group.groupId),
                      ),
                      secondary: HuddleAvatar(
                        name: group.name,
                        photoUrl: group.photoUrl,
                        size: 38,
                      ),
                      title: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              );
            },
          ),
          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: _people,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snapshot.data!.docs.where((doc) {
                final Map<String, dynamic> data = doc.data();
                return doc.id != _service.uid &&
                    _matches(
                      '${data['fullName'] ?? ''} ${data['username'] ?? ''}',
                    );
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('People'),
                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nobody found.'),
                    ),
                  for (final doc in docs)
                    CheckboxListTile(
                      value: _users.contains(doc.id),
                      onChanged: (on) => setState(
                            () => on == true
                            ? _users.add(doc.id)
                            : _users.remove(doc.id),
                      ),
                      secondary: HuddleAvatar(
                        name: (doc.data()['fullName'] ?? '').toString(),
                        photoUrl: (doc.data()['photoUrl'] ?? '').toString(),
                        size: 38,
                      ),
                      title: Text(
                        (doc.data()['fullName'] ?? doc.data()['username'] ?? '')
                            .toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('@${doc.data()['username'] ?? ''}'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}