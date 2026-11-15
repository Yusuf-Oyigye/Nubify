
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/nubi_service.dart';

class NubiMindrushScreen extends StatefulWidget {
  const NubiMindrushScreen({super.key});

  @override
  State<NubiMindrushScreen> createState() =>
      _NubiMindrushScreenState();
}

class _NubiMindrushScreenState
    extends State<NubiMindrushScreen> {
  final TextEditingController _roomCode =
  TextEditingController();

  bool _busy = false;
  int _perPlayer = 5;
  int _answerSeconds = 20;
  String _mode = 'classic';


  void _message(Object message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString())),
    );
  }

  Future<void> _create(String sourceId) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {

      final result = await NubiService.call(
        'nubiCreateRoom',
        {
          'sourceId': sourceId,
          'perPlayer': _perPlayer,
          'answerSeconds': _answerSeconds,
          'mode': _mode,
        },
      );


      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NubiMindrushRoomScreen(
            roomId: result['roomId'].toString(),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _roomCode.text.trim();

    if (code.isEmpty) {
      _message('Enter a room code.');
      return;
    }

    setState(() => _busy = true);

    try {
      await NubiService.call(
        'nubiJoinRoom',
        {'roomId': code},
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NubiMindrushRoomScreen(
            roomId: code,
          ),
        ),
      );
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _roomCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindRush'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: Color(0xFFD97706),
            size: 64,
          ),

          const SizedBox(height: 12),

          Text(
            'Challenge Friends. Level Up.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme.titleLarge,
          ),

          const SizedBox(height: 22),

          const Text(
            'Create a Classic Room',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 10),


          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(
              labelText: 'Game Mode',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'classic',
                child: Text('Classic'),
              ),
              DropdownMenuItem(
                value: 'exam',
                child: Text('Exam Mode'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _mode = value);
              }
            },
          ),
          const SizedBox(height: 12),


          DropdownButtonFormField<int>(
            initialValue: _perPlayer,
            decoration: const InputDecoration(
              labelText: 'Questions per player',
              border: OutlineInputBorder(),
            ),
            items: [3, 5].map((n) {
              return DropdownMenuItem(
                value: n,
                child: Text('$n questions'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _perPlayer = value);
              }
            },
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<int>(
            initialValue: _answerSeconds,
            decoration: const InputDecoration(
              labelText: 'Answer duration',
              border: OutlineInputBorder(),
            ),
            items: [15, 20, 30].map((n) {
              return DropdownMenuItem(
                value: n,
                child: Text('$n seconds'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _answerSeconds = value);
              }
            },
          ),

          const SizedBox(height: 16),

          const Text(
            'Select a saved lecture:',
          ),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: NubiService.sources
                .orderBy('createdAt', descending: true)
                .limit(25)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }

              final docs = snapshot.data!.docs
                  .where((doc) =>
              doc.data()['status'] == 'ready')
                  .toList();

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Add a lecture to My Deck first.',
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  return Card(
                    child: ListTile(
                      title: Text(
                        (doc.data()['title'] ??
                            'Lecture')
                            .toString(),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline,
                      ),
                      onTap: _busy
                          ? null
                          : () => _create(doc.id),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const Divider(height: 35),

          const Text(
            'Join a Friend',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _roomCode,
            decoration: const InputDecoration(
              labelText: 'MindRush Room Code',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _busy ? null : _join,
            icon: const Icon(Icons.group_add),
            label: const Text('Join Room'),
          ),

          if (_busy)
            const LinearProgressIndicator(),
        ],
      ),
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
