import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/audio_call_screen.dart';

//===============================
// INCOMING CALL LISTENER
//===============================

class IncomingCallListener
    extends StatefulWidget {
  const IncomingCallListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<IncomingCallListener>
  createState() =>
      _IncomingCallListenerState();
}

//===============================
// INCOMING CALL STATE
//===============================

class _IncomingCallListenerState
    extends State<
        IncomingCallListener> {
  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  StreamSubscription<
      QuerySnapshot<
          Map<String, dynamic>>>?
  _subscription;

  final Set<String>
  _handledCalls =
  <String>{};

  bool _dialogOpen =
  false;

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();

    _startListening();
  }

  //===============================
  // LISTEN
  //===============================

  void _startListening() {
    final String? uid =
        _auth.currentUser?.uid;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    _subscription =
        _firestore
            .collection(
          'calls',
        )
            .where(
          'calleeId',
          isEqualTo:
          uid,
        )
            .snapshots()
            .listen(
              (
              QuerySnapshot<
                  Map<String, dynamic>>
              snapshot,
              ) {
            for (final QueryDocumentSnapshot<
                Map<String, dynamic>>
            document
            in snapshot.docs) {
              final Map<String, dynamic>
              data =
              document.data();

              if ((data['status'] ?? '')
                  .toString() !=
                  'ringing') {
                continue;
              }

              if (_handledCalls.contains(
                document.id,
              ) ||
                  _dialogOpen) {
                continue;
              }

              _handledCalls.add(
                document.id,
              );

              _showIncomingCall(
                document.id,
                data,
              );

              break;
            }
          },
          onError:
              (_) {},
        );
  }

  //===============================
  // SHOW CALL
  //===============================

  Future<void> _showIncomingCall(
      String callId,
      Map<String, dynamic> callData,
      ) async {
    final String callerId =
    (callData['callerId'] ?? '')
        .toString();

    if (callerId.isEmpty ||
        !mounted) {
      return;
    }

    _dialogOpen =
    true;

    String callerName =
        'Nubify user';

    String callerPhotoUrl =
        '';

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      userSnapshot =
      await _firestore
          .collection(
        'users',
      )
          .doc(
        callerId,
      )
          .get();

      final Map<String, dynamic>
      user =
          userSnapshot.data() ??
              <String, dynamic>{};

      callerName =
          (user['fullName'] ??
              user['username'] ??
              'Nubify user')
              .toString();

      callerPhotoUrl =
          (user['photoUrl'] ?? '')
              .toString();
    } catch (_) {}

    if (!mounted) {
      _dialogOpen =
      false;

      return;
    }

    final bool? accept =
    await showDialog<bool>(
      context:
      context,
      barrierDismissible:
      false,
      builder:
          (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Incoming audio call',
          ),
          content:
          Column(
            mainAxisSize:
            MainAxisSize.min,
            children:
            <Widget>[
              CircleAvatar(
                radius:
                34,
                backgroundImage:
                callerPhotoUrl
                    .trim()
                    .isNotEmpty
                    ? NetworkImage(
                  callerPhotoUrl,
                )
                    : null,
                child:
                callerPhotoUrl
                    .trim()
                    .isEmpty
                    ? const Icon(
                  Icons
                      .person_rounded,
                )
                    : null,
              ),

              const SizedBox(
                height:
                12,
              ),

              Text(
                callerName,
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.w800,
                  fontSize:
                  17,
                ),
              ),

              const SizedBox(
                height:
                4,
              ),

              const Text(
                'is calling you',
              ),
            ],
          ),
          actions:
          <Widget>[
            TextButton.icon(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              icon:
              const Icon(
                Icons
                    .call_end_rounded,
                color:
                Colors.redAccent,
              ),
              label:
              const Text(
                'Decline',
              ),
            ),

            FilledButton.icon(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon:
              const Icon(
                Icons.call_rounded,
              ),
              label:
              const Text(
                'Answer',
              ),
            ),
          ],
        );
      },
    );

    _dialogOpen =
    false;

    if (accept ==
        true) {
      if (!mounted) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder:
              (_) =>
              AudioCallScreen(
                incoming:
                true,

                callId:
                callId,

                otherUserId:
                callerId,

                otherName:
                callerName,

                otherPhotoUrl:
                callerPhotoUrl,
              ),
        ),
      );

      return;
    }

    try {
      await _firestore
          .collection(
        'calls',
      )
          .doc(
        callId,
      )
          .set(
        <String, dynamic>{
          'status':
          'declined',

          'declinedAt':
          FieldValue
              .serverTimestamp(),

          'updatedAt':
          FieldValue
              .serverTimestamp(),
        },
        SetOptions(
          merge:
          true,
        ),
      );
    } catch (_) {}
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    return widget.child;
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _subscription
        ?.cancel();

    super.dispose();
  }
}