import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat/chat_message.dart';
import '../../services/chat/chat_sevice.dart';
import '../../services/profile/profile_service.dart';
import '../../widgets/common/full_photo_viewer.dart';
import '../../widgets/chat/nubify_chat_style.dart';
import 'chat_media_screen.dart';
import '../profile/profile_screen.dart';

//===============================
// CONTACT INFO SCREEN
//
// Opens when you tap the name or photo at the top of a
// chat, like WhatsApp: big photo, quick actions, about,
// shared media, links and docs, then block and report.
//===============================

class ChatContactInfoScreen extends StatefulWidget {
  const ChatContactInfoScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
    required this.otherUsername,
    required this.otherPhotoUrl,
    required this.isBlocked,
    required this.onCall,
    required this.onSearch,
    required this.onCopyLink,
    required this.onReport,
    required this.onToggleBlock,
  });

  final String otherUserId;

  final String otherName;

  final String otherUsername;

  final String otherPhotoUrl;

  // These come from the chat screen, so they work the
  // same way as the actions in its ⋮ menu.
  final bool Function() isBlocked;

  final VoidCallback onCall;

  final VoidCallback onSearch;

  final Future<void> Function() onCopyLink;

  final Future<void> Function() onReport;

  final Future<void> Function() onToggleBlock;

  @override
  State<ChatContactInfoScreen> createState() => _ChatContactInfoScreenState();
}

//===============================
// CONTACT INFO STATE
//===============================

class _ChatContactInfoScreenState extends State<ChatContactInfoScreen> {
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  final ChatService _chatService = ChatService();

  final ProfileService _profileService = ProfileService();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream =
      _profileService.userStream(widget.otherUserId);

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream =
      _chatService.getMessages(widget.otherUserId);

  //===============================
  // HELPERS
  //===============================

  String _field(Map<String, dynamic> data, String key, String fallback) {
    final String value = (data[key] ?? '').toString().trim();

    return value.isNotEmpty ? value : fallback.trim();
  }

  Future<void> _openUrl(String url) async {
    final Uri? uri = Uri.tryParse(url);

    if (uri == null) {
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  //===============================
  // OPEN SCREENS
  //===============================

  void _openPhoto(String name, String photoUrl) {
    if (photoUrl.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FullPhotoViewer(title: name, photoUrl: photoUrl),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(uid: widget.otherUserId),
      ),
    );
  }

  void _openAllMedia([int tab = 0]) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatMediaScreen(
          otherUserId: widget.otherUserId,
          otherName: widget.otherName,
          initialTab: tab,
        ),
      ),
    );
  }

  void _openMedia(ChatMessage message) {
    if (message.isVideo) {
      _openUrl(message.mediaUrl);

      return;
    }

    _openPhoto(widget.otherName, message.mediaUrl);
  }

  void _searchChat() {
    Navigator.pop(context);

    widget.onSearch();
  }

  Future<void> _toggleBlock() async {
    await widget.onToggleBlock();

    if (mounted) {
      setState(() {});
    }
  }

  //===============================
  // CARD
  //===============================

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    final bool dark = NubifyChatStyle.isDark(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE3E9F3),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }

  //===============================
  // HEADER — PHOTO, NAME, USERNAME
  //===============================

  Widget _header(String name, String username, String photoUrl) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        children: <Widget>[
          Semantics(
            button: photoUrl.isNotEmpty,
            label: 'Profile photo of $name',
            child: GestureDetector(
              onTap: () {
                _openPhoto(name, photoUrl);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: NubifyChatStyle.royal.withValues(alpha: 0.30),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: NubifyChatAvatar(photoUrl: photoUrl, radius: 58),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),

          if (username.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '@$username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  //===============================
  // QUICK ACTIONS
  //===============================

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: <Widget>[
          _actionTile(
            icon: Icons.call_rounded,
            label: 'Audio',
            onTap: widget.onCall,
          ),
          const SizedBox(width: 10),
          _actionTile(
            icon: Icons.search_rounded,
            label: 'Search',
            onTap: _searchChat,
          ),
          const SizedBox(width: 10),
          _actionTile(
            icon: Icons.person_rounded,
            label: 'Profile',
            onTap: _openProfile,
          ),
          const SizedBox(width: 10),
          _actionTile(
            icon: Icons.link_rounded,
            label: 'Copy link',
            onTap: widget.onCopyLink,
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool dark = NubifyChatStyle.isDark(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(18);

    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: radius,
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE3E9F3),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: NubifyChatStyle.royal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: NubifyChatStyle.royal, size: 21),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  //===============================
  // ABOUT
  //===============================

  Widget _about(String about, String faculty) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle('About'),

          if (about.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              about,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ],

          if (faculty.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.school_rounded,
                  color: NubifyChatStyle.royal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    faculty,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  //===============================
  // MEDIA, LINKS AND DOCS
  //===============================

  Widget _mediaCard() {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final List<ChatMessage> messages =
                (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(ChatMessage.fromDocument)
                    .toList();

            final List<ChatMessage> media = messages
                .where(
                  (ChatMessage message) =>
                      (message.isImage || message.isVideo) &&
                      message.mediaUrl.trim().isNotEmpty,
                )
                .toList();

            final int documents = messages
                .where((ChatMessage message) => message.isDocument)
                .length;

            final int links = messages.fold<int>(
              0,
              (int total, ChatMessage message) =>
                  total + _urlRegex.allMatches(message.text).length,
            );

            return _card(
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openAllMedia,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _sectionTitle('Media, links and docs'),
                          ),
                          Text(
                            'See all',
                            style: TextStyle(
                              color: NubifyChatStyle.royal,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  if (media.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 10, 4),
                      child: Text(
                        snapshot.connectionState == ConnectionState.waiting
                            ? 'Loading…'
                            : 'Photos and videos you share in this chat will show here.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 10),
                        itemCount: media.length > 12 ? 12 : media.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (BuildContext context, int index) {
                          return _thumbnail(media[index]);
                        },
                      ),
                    ),

                  const SizedBox(height: 12),

                  Row(
                    children: <Widget>[
                      _countChip(
                        icon: Icons.photo_library_rounded,
                        label: '${media.length} media',
                        onTap: () => _openAllMedia(0),
                      ),
                      const SizedBox(width: 8),
                      _countChip(
                        icon: Icons.link_rounded,
                        label: '$links links',
                        onTap: () => _openAllMedia(1),
                      ),
                      const SizedBox(width: 8),
                      _countChip(
                        icon: Icons.description_rounded,
                        label: '$documents docs',
                        onTap: () => _openAllMedia(2),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
    );
  }

  Widget _thumbnail(ChatMessage message) {
    final bool dark = NubifyChatStyle.isDark(context);

    return Semantics(
      button: true,
      label: message.isVideo ? 'Open video' : 'Open photo',
      child: GestureDetector(
        onTap: () {
          _openMedia(message);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 84,
            height: 84,
            child: message.isVideo
                ? DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: NubifyChatStyle.outgoing,
                    ),
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : Image.network(
                    message.mediaUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 252,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: dark
                          ? const Color(0xFF223042)
                          : const Color(0xFFE7EEF8),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _countChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      color: NubifyChatStyle.royal.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: NubifyChatStyle.royal, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //===============================
  // BLOCK AND REPORT
  //===============================

  Widget _safety(String name) {
    final bool blocked = widget.isBlocked();

    return _card(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: <Widget>[
          _dangerRow(
            icon: blocked ? Icons.lock_open_rounded : Icons.block_rounded,
            label: blocked ? 'Unblock $name' : 'Block $name',
            onTap: _toggleBlock,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          _dangerRow(
            icon: Icons.flag_rounded,
            label: 'Report $name',
            onTap: widget.onReport,
          ),
        ],
      ),
    );
  }

  Widget _dangerRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: NubifyChatStyle.danger),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: NubifyChatStyle.danger,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contact info',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
            ) {
              final Map<String, dynamic> data =
                  snapshot.data?.data() ?? <String, dynamic>{};

              final String name = _field(data, 'fullName', widget.otherName);
              final String username = _field(
                data,
                'username',
                widget.otherUsername,
              );
              final String photoUrl = _field(
                data,
                'photoUrl',
                widget.otherPhotoUrl,
              );
              final String about = _field(data, 'favoriteQuote', '');
              final String faculty = _field(data, 'faculty', '');

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: <Widget>[
                  _header(name, username, photoUrl),
                  _actions(),
                  if (about.isNotEmpty || faculty.isNotEmpty)
                    _about(about, faculty),
                  _mediaCard(),
                  _safety(name),
                ],
              );
            },
      ),
    );
  }
}
