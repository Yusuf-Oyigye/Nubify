
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/group_chat_service.dart';

//===================================================
// GROUP JOIN REQUESTS SCREEN
//===================================================

class GroupJoinRequestsScreen extends StatefulWidget {
  const GroupJoinRequestsScreen({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<GroupJoinRequestsScreen> createState() =>
      _GroupJoinRequestsScreenState();
}

//===================================================
// GROUP JOIN REQUESTS STATE
//===================================================

class _GroupJoinRequestsScreenState
    extends State<GroupJoinRequestsScreen> {
  static const Color _blue = Color(0xFF29B6F6);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final GroupChatService _groupService =
  GroupChatService();

  final Set<String> _processing = <String>{};

  //===================================================
  // APPROVE OR REJECT REQUEST
  //===================================================

  Future<void> _handleRequest({
    required String userId,
    required bool approve,
  }) async {
    if (_processing.contains(userId)) return;

    setState(() {
      _processing.add(userId);
    });

    try {
      if (approve) {
        await _groupService.approveJoinRequest(
          groupId: widget.groupId,
          userId: userId,
        );
      } else {
        await _groupService.rejectJoinRequest(
          groupId: widget.groupId,
          userId: userId,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Student added to the group.'
                : 'Join request rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to process request: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing.remove(userId);
        });
      }
    }
  }

  //===================================================
  // STUDENT REQUEST CARD
  //===================================================

  Widget _requestCard(String userId) {
    final bool busy = _processing.contains(userId);

    return FutureBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      future: _firestore
          .collection('users')
          .doc(userId)
          .get(),

      builder: (context, snapshot) {
        final Map<String, dynamic> user =
            snapshot.data?.data() ??
                <String, dynamic>{};

        final String name =
        (user['fullName'] ?? 'Student').toString();

        final String username =
        (user['username'] ?? '').toString();

        final String photo =
        (user['photoUrl'] ?? '').toString();

        return Card(
          margin: const EdgeInsets.symmetric(
            vertical: 7,
          ),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor:
                      _blue.withValues(alpha: 0.18),
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,
                      child: photo.isEmpty
                          ? const Icon(
                        Icons.person_rounded,
                        color: _blue,
                      )
                          : null,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),

                          if (username.isNotEmpty)
                            Text(
                              '@$username',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),

                          const SizedBox(height: 4),

                          const Text(
                            'Wants to join your group',
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                if (busy)
                  const Center(
                    child: CircularProgressIndicator(
                      color: _blue,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _handleRequest(
                              userId: userId,
                              approve: false,
                            );
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                          label: const Text('Reject'),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _blue,
                          ),
                          onPressed: () {
                            _handleRequest(
                              userId: userId,
                              approve: true,
                            );
                          },
                          icon: const Icon(
                            Icons.check_rounded,
                          ),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  //===================================================
  // BUILD REQUEST LIST
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Join requests',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('chatGroups')
            .doc(widget.groupId)
            .collection('joinRequests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load join requests.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: _blue,
              ),
            );
          }

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.how_to_reg_outlined,
                    size: 55,
                    color: _blue,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No pending join requests',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'New requests will appear here.',
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _requestCard(
                requests[index].id,
              );
            },
          );
        },
      ),
    );
  }
}
