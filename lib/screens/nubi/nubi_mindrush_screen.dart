
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/nubi_service.dart';
import 'nubi_learning_screens.dart';

// ===========================================
// MINDRUSH LOOK
// ===========================================

const Color _rushAmber = Color(0xFFF59E0B);
const Color _rushViolet = Color(0xFF7C3AED);
const Color _rushNavy = Color(0xFF14286B);

const LinearGradient _rushGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF7C3AED)],
);

// Most players a battle can hold, matching the backend.
const int _maxPlayers = 5;

String _friendlyError(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.message ?? 'Something went wrong. Please try again.';
  }
  return error.toString().replaceFirst('Bad state: ', '');
}

// ===========================================
// JOIN A ROOM AND OPEN IT
//
// Used by invites, public battles, room codes and the
// invite notification.
// ===========================================

Future<void> joinMindrushRoom(BuildContext context, String roomId) async {
  try {
    await NubiService.call('nubiJoinRoom', {'roomId': roomId});

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NubiMindrushRoomScreen(roomId: roomId),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }
}

// ===========================================
// MINDRUSH HOME
//
// Create: pick a lecture, choose who can join, invite
// friends, set the rules, start.
// Join: your invites, public battles, or a room code.
// ===========================================

class NubiMindrushScreen extends StatefulWidget {
  const NubiMindrushScreen({super.key});

  @override
  State<NubiMindrushScreen> createState() => _NubiMindrushScreenState();
}

class _NubiMindrushScreenState extends State<NubiMindrushScreen> {
  final TextEditingController _roomCode = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _lectures = NubiService
      .sources
      .orderBy('createdAt', descending: true)
      .limit(25)
      .snapshots();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _invites = NubiService
      .db
      .collection('mindrushRooms')
      .where('invited', arrayContains: NubiService.uid)
      .limit(20)
      .snapshots();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _publicRooms =
      NubiService.db
          .collection('mindrushRooms')
          .where('visibility', isEqualTo: 'public')
          .where('status', isEqualTo: 'waiting')
          .limit(30)
          .snapshots();

  bool _busy = false;
  String? _lectureId;
  String _visibility = 'friends';
  List<_RushFriend> _invited = <_RushFriend>[];
  int _perPlayer = 5;
  int _answerSeconds = 20;
  String _mode = 'classic';

  @override
  void dispose() {
    _roomCode.dispose();
    super.dispose();
  }

  void _message(Object message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_friendlyError(message))));
  }

  // ===========================================
  // CREATE
  // ===========================================

  Future<void> _create() async {
    final String? lectureId = _lectureId;

    if (_busy || lectureId == null) return;

    setState(() => _busy = true);

    try {
      final result = await NubiService.call('nubiCreateRoom', {
        'sourceId': lectureId,
        'perPlayer': _perPlayer,
        'answerSeconds': _answerSeconds,
        'mode': _mode,
        'visibility': _visibility,
        'invitedUids': _invited.map((_RushFriend f) => f.uid).toList(),
      });

      if (!mounted) return;

      setState(() => _invited = <_RushFriend>[]);

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              NubiMindrushRoomScreen(roomId: result['roomId'].toString()),
        ),
      );
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join(String roomId) async {
    if (_busy) return;

    setState(() => _busy = true);
    await joinMindrushRoom(context, roomId);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _joinWithCode() async {
    final String code = _roomCode.text.trim();

    if (code.isEmpty) {
      _message('Enter a room code.');
      return;
    }

    FocusScope.of(context).unfocus();
    await _join(code);
  }

  Future<void> _pickFriends() async {
    final List<_RushFriend>? picked =
        await showModalBottomSheet<List<_RushFriend>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _FriendPickerSheet(initial: _invited),
        );

    if (picked != null && mounted) {
      setState(() => _invited = picked);
    }
  }

  // ===========================================
  // SHARED PIECES
  // ===========================================

  BoxDecoration _card(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFE3E9F3),
      ),
    );
  }

  Widget _step(int number, String title, String subtitle, Widget child) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: _card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: _rushGradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _choiceChips<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((T value) {
        final bool on = value == selected;

        return ChoiceChip(
          label: Text(label(value)),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => onSelected(value),
          selectedColor: _rushNavy,
          labelStyle: TextStyle(
            color: on ? Colors.white : null,
            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
      }).toList(),
    );
  }

  // ===========================================
  // HERO
  // ===========================================

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _rushGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _rushViolet.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Battle your friends',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Quiz battles on your lectures. Fastest brain wins XP.',
                  style: TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // CREATE TAB
  // ===========================================

  Widget _lecturePicker() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _lectures,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final docs = snapshot.data!.docs
            .where((doc) => doc.data()['status'] == 'ready')
            .toList();

        if (docs.isEmpty) {
          return Row(
            children: <Widget>[
              const Expanded(
                child: Text('Add a lecture to My Deck first.'),
              ),
              TextButton(
                onPressed: () => nubiOpen(context, const NubiDeckScreen()),
                child: const Text('Open My Deck'),
              ),
            ],
          );
        }

        return SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final bool selected = doc.id == _lectureId;

              return Semantics(
                button: true,
                selected: selected,
                child: GestureDetector(
                  onTap: () => setState(() => _lectureId = doc.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 168,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: selected ? _rushGradient : null,
                      color: selected
                          ? null
                          : _rushAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : _rushAmber.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.menu_book_rounded,
                          color: selected ? Colors.white : _rushAmber,
                          size: 20,
                        ),
                        const Spacer(),
                        Text(
                          (doc.data()['title'] ?? 'Lecture').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : null,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _whoCanJoin() {
    Widget option({
      required String value,
      required IconData icon,
      required String title,
      required String subtitle,
    }) {
      final bool selected = _visibility == value;
      final ColorScheme scheme = Theme.of(context).colorScheme;

      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () => setState(() => _visibility = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? _rushNavy
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    icon,
                    color: selected ? Colors.white : _rushViolet,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: selected
                          ? Colors.white70
                          : scheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        option(
          value: 'friends',
          icon: Icons.lock_rounded,
          title: 'Friends only',
          subtitle: 'People you invite or share the code with',
        ),
        const SizedBox(width: 10),
        option(
          value: 'public',
          icon: Icons.public_rounded,
          title: 'Public',
          subtitle: 'Any student can find it and join',
        ),
      ],
    );
  }

  Widget _inviteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_invited.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _invited.map((_RushFriend friend) {
              return InputChip(
                avatar: _RushAvatar(photoUrl: friend.photoUrl, radius: 12),
                label: Text(friend.name),
                onDeleted: () => setState(
                  () => _invited = _invited
                      .where((_RushFriend f) => f.uid != friend.uid)
                      .toList(),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: _pickFriends,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(
            _invited.isEmpty ? 'Choose friends' : 'Change friends',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _rushViolet,
            side: BorderSide(color: _rushViolet.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _createTab() {
    final bool ready = _lectureId != null && !_busy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: <Widget>[
        _step(
          1,
          'Pick a lecture',
          'Questions come from this lecture',
          _lecturePicker(),
        ),
        _step(
          2,
          'Who can join?',
          'Keep it to friends or open it to everyone',
          _whoCanJoin(),
        ),
        _step(
          3,
          'Invite friends',
          'From people you follow or who follow you '
              '(up to ${_maxPlayers - 1})',
          _inviteSection(),
        ),
        _step(
          4,
          'Battle rules',
          'Game mode, questions and time to answer',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _choiceChips<String>(
                values: const <String>['classic', 'exam'],
                selected: _mode,
                label: (v) => v == 'classic' ? 'Classic' : 'Exam mode',
                onSelected: (v) => setState(() => _mode = v),
              ),
              const SizedBox(height: 10),
              _choiceChips<int>(
                values: const <int>[3, 5],
                selected: _perPlayer,
                label: (v) => '$v questions each',
                onSelected: (v) => setState(() => _perPlayer = v),
              ),
              const SizedBox(height: 10),
              _choiceChips<int>(
                values: const <int>[15, 20, 30],
                selected: _answerSeconds,
                label: (v) => '${v}s to answer',
                onSelected: (v) => setState(() => _answerSeconds = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Opacity(
          opacity: ready ? 1 : 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _rushGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: ready
                  ? <BoxShadow>[
                      BoxShadow(
                        color: _rushViolet.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: ready ? _create : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (_busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(Icons.bolt_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _lectureId == null
                            ? 'Pick a lecture to start'
                            : _visibility == 'public'
                            ? 'Create public battle'
                            : 'Create battle',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================
  // JOIN TAB
  // ===========================================

  Widget _sectionLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: _rushViolet),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _roomCard(Map<String, dynamic> room, String roomId, String reason) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> players = List<String>.from(room['players'] ?? []);
    final bool joined = players.contains(NubiService.uid);
    final bool full = players.length >= _maxPlayers;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _card(context),
      child: Row(
        children: <Widget>[
          _RushAvatar(
            photoUrl: (room['hostPhotoUrl'] ?? '').toString(),
            radius: 23,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  (room['lectureTitle'] ?? 'Lecture battle').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.people_alt_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${players.length}/$_maxPlayers players',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _busy || (full && !joined)
                ? null
                : () => _join(roomId),
            style: FilledButton.styleFrom(
              backgroundColor: _rushNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(joined ? 'Open' : full ? 'Full' : 'Join'),
          ),
        ],
      ),
    );
  }

  Widget _roomList({
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String empty,
    required String Function(Map<String, dynamic> room) reason,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Could not load battles right now.'),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(),
          );
        }

        final rooms =
            snapshot.data!.docs
                .where((doc) => doc.data()['status'] == 'waiting')
                .toList()
              ..sort((a, b) {
                final at = a.data()['createdAt'];
                final bt = b.data()['createdAt'];
                if (at is Timestamp && bt is Timestamp) {
                  return bt.compareTo(at);
                }
                return 0;
              });

        if (rooms.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: _card(context),
            child: Text(
              empty,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Column(
          children: rooms
              .map((doc) => _roomCard(doc.data(), doc.id, reason(doc.data())))
              .toList(),
        );
      },
    );
  }

  Widget _joinTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: <Widget>[
        _sectionLabel('Invites for you', Icons.mail_rounded),
        _roomList(
          stream: _invites,
          empty: 'No invites yet. When a friend invites you, it shows here.',
          reason: (room) => '${room['hostName'] ?? 'A friend'} invited you',
        ),
        const SizedBox(height: 6),
        _sectionLabel('Public battles', Icons.public_rounded),
        _roomList(
          stream: _publicRooms,
          empty: 'No public battles open right now. Create one!',
          reason: (room) => '${room['hostName'] ?? 'A student'}\'s battle',
        ),
        const SizedBox(height: 6),
        _sectionLabel('Have a room code?', Icons.key_rounded),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _card(context),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _roomCode,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _joinWithCode(),
                  decoration: const InputDecoration(
                    hintText: 'Paste the room code',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Paste',
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: () async {
                  final ClipboardData? data = await Clipboard.getData(
                    Clipboard.kTextPlain,
                  );
                  final String text = (data?.text ?? '').trim();
                  if (text.isNotEmpty) _roomCode.text = text;
                },
              ),
              FilledButton(
                onPressed: _busy ? null : _joinWithCode,
                style: FilledButton.styleFrom(
                  backgroundColor: _rushNavy,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Join'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================
  // BUILD
  // ===========================================

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'MindRush',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: Column(
          children: <Widget>[
            _hero(),
            Container(
              height: 46,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1C2735) : const Color(0xFFE8EEF7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: _rushNavy,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                tabs: const <Widget>[
                  Tab(
                    height: 38,

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.add_circle_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Create'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.sports_esports_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Join'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(children: <Widget>[_createTab(), _joinTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================
// FRIEND PICKER
//
// People you follow and people who follow you. Pick up
// to four to invite.
// ===========================================

class _RushFriend {
  const _RushFriend({
    required this.uid,
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.relation,
  });

  final String uid;
  final String name;
  final String username;
  final String photoUrl;

  // "Friends", "Follows you" or "You follow".
  final String relation;
}

class _FriendPickerSheet extends StatefulWidget {
  const _FriendPickerSheet({required this.initial});

  final List<_RushFriend> initial;

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  late final Map<String, _RushFriend> _selected = <String, _RushFriend>{
    for (final _RushFriend friend in widget.initial) friend.uid: friend,
  };

  late final Future<List<_RushFriend>> _friends = _loadFriends();

  String _search = '';

  static List<String> _ids(dynamic value) =>
      value is List ? value.map((dynamic id) => id.toString()).toList() : [];

  Future<List<_RushFriend>> _loadFriends() async {
    final String uid = NubiService.uid;
    final me = await NubiService.db.collection('users').doc(uid).get();
    final Map<String, dynamic> data = me.data() ?? <String, dynamic>{};

    final Set<String> followers = _ids(data['followers']).toSet();
    final Set<String> following = _ids(data['following']).toSet();
    final List<String> everyone = <String>{...following, ...followers}
        .where((String id) => id.isNotEmpty && id != uid)
        .take(300)
        .toList();

    final List<_RushFriend> friends = <_RushFriend>[];

    // Firestore reads up to 30 people per query.
    for (int start = 0; start < everyone.length; start += 30) {
      final chunk = everyone.sublist(
        start,
        start + 30 > everyone.length ? everyone.length : start + 30,
      );
      final users = await NubiService.db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in users.docs) {
        final user = doc.data();
        final String fullName = (user['fullName'] ?? '').toString().trim();
        final String username = (user['username'] ?? '').toString().trim();
        final bool both =
            followers.contains(doc.id) && following.contains(doc.id);

        friends.add(
          _RushFriend(
            uid: doc.id,
            name: fullName.isNotEmpty
                ? fullName
                : username.isNotEmpty
                ? username
                : 'Nubify student',
            username: username,
            photoUrl: (user['photoUrl'] ?? '').toString(),
            relation: both
                ? 'Friends'
                : followers.contains(doc.id)
                ? 'Follows you'
                : 'You follow',
          ),
        );
      }
    }

    friends.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return friends;
  }

  void _toggle(_RushFriend friend) {
    setState(() {
      if (_selected.containsKey(friend.uid)) {
        _selected.remove(friend.uid);
      } else if (_selected.length < _maxPlayers - 1) {
        _selected[friend.uid] = friend;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A battle holds 5 players, so pick up to 4.'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Invite friends',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Text(
                    '${_selected.length}/${_maxPlayers - 1}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (value) =>
                    setState(() => _search = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search followers and following',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<_RushFriend>>(
                future: _friends,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Could not load your friends.'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final friends = snapshot.data!
                      .where(
                        (f) =>
                            _search.isEmpty ||
                            f.name.toLowerCase().contains(_search) ||
                            f.username.toLowerCase().contains(_search),
                      )
                      .toList();

                  if (friends.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          snapshot.data!.isEmpty
                              ? 'Follow some students first, then you can invite them here.'
                              : 'No one matches that search.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final bool picked = _selected.containsKey(friend.uid);

                      return CheckboxListTile(
                        value: picked,
                        onChanged: (_) => _toggle(friend),
                        activeColor: _rushNavy,
                        secondary: _RushAvatar(
                          photoUrl: friend.photoUrl,
                          radius: 21,
                        ),
                        title: Text(
                          friend.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          friend.username.isEmpty
                              ? friend.relation
                              : '@${friend.username} · ${friend.relation}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, _selected.values.toList()),
                  style: FilledButton.styleFrom(
                    backgroundColor: _rushNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Done'
                        : 'Invite ${_selected.length} '
                              '${_selected.length == 1 ? 'friend' : 'friends'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RushAvatar extends StatelessWidget {
  const _RushAvatar({required this.photoUrl, required this.radius});

  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String url = photoUrl.trim();

    return CircleAvatar(
      radius: radius,
      backgroundColor: _rushViolet.withValues(alpha: 0.12),
      backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      child: url.isEmpty
          ? Icon(Icons.person_rounded, color: _rushViolet, size: radius)
          : null,
    );
  }
}

// ===========================================
// REAL-TIME MINDRUSH ROOM
// ===========================================

class NubiMindrushRoomScreen
    extends StatefulWidget {
  const NubiMindrushRoomScreen({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  State<NubiMindrushRoomScreen> createState() =>
      _NubiMindrushRoomScreenState();
}

class _NubiMindrushRoomScreenState
    extends State<NubiMindrushRoomScreen> {
  Timer? _timer;

  bool _busy = false;
  bool _advancing = false;
  int _now = DateTime.now().millisecondsSinceEpoch;
  int? _removedOption;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (mounted) {
          setState(() {
            _now =
                DateTime.now().millisecondsSinceEpoch;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _message(Object message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toString()),
      ),
    );
  }

  Future<void> _call(
      String name,
      Map<String, dynamic> data,
      ) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final result = await NubiService.call(
        name,
        {
          'roomId': widget.roomId,
          ...data,
        },
      );

      if (mounted &&
          name == 'nubiAnswerRoom') {
        _message(
          result['correct'] == true
              ? 'Correct! +${result['earned'] ?? 0} XP'
              : 'Incorrect. Steal available!',
        );
      }
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance() async {
    if (_advancing) return;
    _advancing = true;

    try {
      await NubiService.call(
        'nubiAdvanceRoom',
        {'roomId': widget.roomId},
      );
    } catch (_) {
      // A second client may already have advanced.
    } finally {
      _advancing = false;
    }
  }

  Future<void> _powerUp(String power) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final result = await NubiService.call(
        'nubiUsePowerUp',
        {
          'roomId': widget.roomId,
          'power': power,
        },
      );

      if (!mounted) return;

      if (result.containsKey('removeOption')) {
        setState(() {
          _removedOption =
              (result['removeOption'] as num).toInt();
        });
      } else {
        _message('10 extra seconds granted.');
      }
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = NubiService.db
        .collection('mindrushRooms')
        .doc(widget.roomId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindRush Battle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy room code',
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: widget.roomId),
              );
              if (context.mounted) {
                _message('Room code copied.');
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final room = snapshot.data!.data();

          if (room == null) {
            return const Center(
              child: Text('Room unavailable.'),
            );
          }

          final status =
          (room['status'] ?? '').toString();

          final players = List<String>.from(
            room['players'] ?? [],
          );

          final scores =
          Map<String, dynamic>.from(
            room['scores'] ?? {},
          );

          final isHost =
              room['ownerUid'] == NubiService.uid;

          final secondsLeft = (
              ((room['deadline'] ?? 0) as num).toInt()
                  - _now
          ) ~/ 1000;

          if (status == 'running' &&
              secondsLeft < 0) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) {
              if (mounted) _advance();
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Room: ${widget.roomId}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Players: ${players.length}',
                style: Theme.of(context)
                    .textTheme.titleMedium,
              ),

              for (final player in players)
                ListTile(
                  leading: const Icon(
                    Icons.person_rounded,
                  ),
                  title: Text(
                    player == NubiService.uid
                        ? 'You'
                        : 'Student ${player.substring(0, player.length > 7 ? 7 : player.length)}',
                  ),
                  trailing: Text(
                    '${scores[player] ?? 0} pts',
                  ),
                ),

              const Divider(),

              if (status == 'waiting') ...[
                const Text(
                  'Share the room code with friends. '
                      'At least two players must join.',
                ),

                const SizedBox(height: 14),

                if (isHost)
                  FilledButton(
                    onPressed: _busy || players.length < 2
                        ? null
                        : () => _call(
                      'nubiStartRoom', {},
                    ),
                    child: const Text('Start Battle'),
                  ),
              ],

              if (status == 'preparing')
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Preparing academic questions...'),
                  ],
                ),

              if (status == 'running') ...[
                Text(
                  'Round ${((room['roundIndex'] ?? 0) as num).toInt() + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  room['phase'] == 'steal'
                      ? '⚡ STEAL AVAILABLE'
                      : room['turnUid'] ==
                      NubiService.uid
                      ? 'YOUR TURN'
                      : 'Another student’s turn',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFFD97706),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Time left: ${secondsLeft < 0 ? 0 : secondsLeft}s',
                ),

                const SizedBox(height: 18),

                Text(
                  (room['questionView']?['question']
                      ?? '')
                      .toString(),
                  style: Theme.of(context)
                      .textTheme.titleLarge,
                ),

                const SizedBox(height: 12),

                for (int i = 0;
                i <
                    ((room['questionView']?['options']
                    as List?)?.length ?? 0);
                i++)
                  if (_removedOption != i)
                    Card(
                      child: ListTile(
                        title: Text(
                          room['questionView']['options']
                          [i]
                              .toString(),
                        ),
                        onTap: !_busy &&
                            secondsLeft > 0 &&
                            (room['turnUid'] ==
                                NubiService.uid ||
                                room['phase'] == 'steal')
                            ? () => _call(
                          'nubiAnswerRoom',
                          {'choice': i},
                        )
                            : null,
                      ),
                    ),

                const SizedBox(height: 12),

                if (room['turnUid'] ==
                    NubiService.uid &&
                    room['phase'] == 'answer')
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _powerUp('hint'),
                        child: const Text('Hint'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _powerUp('extraTime'),
                        child: const Text('+10 Seconds'),
                      ),
                    ],
                  ),
              ],

              if (status == 'finished') ...[
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 65,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Battle Finished!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: const Text('Finish'),
                ),
              ],

              if (_busy)
                const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }
}
