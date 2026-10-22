import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

//===============================
// AUDIO CALL SCREEN
//===============================

class AudioCallScreen extends StatefulWidget {
  const AudioCallScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
    required this.otherPhotoUrl,
    this.callId,
    this.incoming = false,
  });

  final String otherUserId;
  final String otherName;
  final String otherPhotoUrl;

  final String? callId;

  final bool incoming;

  @override
  State<AudioCallScreen> createState() =>
      _AudioCallScreenState();
}

//===============================
// AUDIO CALL STATE
//===============================

class _AudioCallScreenState
    extends State<AudioCallScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  RTCPeerConnection?
  _peerConnection;

  MediaStream?
  _localStream;

  StreamSubscription<
      DocumentSnapshot<
          Map<String, dynamic>>>?
  _callSubscription;

  StreamSubscription<
      QuerySnapshot<
          Map<String, dynamic>>>?
  _candidateSubscription;

  String _callId =
      '';

  String _statusText =
      'Preparing call...';

  bool _muted =
  false;

  bool _speakerOn =
  false;

  bool _ending =
  false;

  bool _finishedLocally =
  false;

  bool _remoteDescriptionSet =
  false;

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  //===============================
  // INITIALIZE
  //===============================

  Future<void> _initialize() async {
    final PermissionStatus microphone =
    await Permission
        .microphone
        .request();

    if (!microphone.isGranted) {
      _setStatus(
        'Microphone permission is required.',
      );

      return;
    }

    try {
      await _createPeerConnection();

      if (widget.incoming) {
        await _answerIncomingCall();
      } else {
        await _startOutgoingCall();
      }
    } catch (error) {
      _setStatus(
        error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  //===============================
  // PEER CONNECTION
  //===============================

  Future<void>
  _createPeerConnection() async {
    final Map<String, dynamic>
    configuration =
    <String, dynamic>{
      'iceServers':
      <Map<String, dynamic>>[
        <String, dynamic>{
          'urls':
          <String>[
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
          ],
        },
      ],
    };

    _peerConnection =
    await createPeerConnection(
      configuration,
    );

    _localStream =
    await navigator
        .mediaDevices
        .getUserMedia(
      <String, dynamic>{
        'audio':
        true,
        'video':
        false,
      },
    );

    for (final MediaStreamTrack track
    in _localStream!
        .getAudioTracks()) {
      await _peerConnection!
          .addTrack(
        track,
        _localStream!,
      );
    }

    _peerConnection!
        .onConnectionState =
        (
        RTCPeerConnectionState state,
        ) {
      if (!mounted) {
        return;
      }

      switch (state) {
        case RTCPeerConnectionState
            .RTCPeerConnectionStateConnected:
          _setStatus(
            'Connected',
          );
          break;

        case RTCPeerConnectionState
            .RTCPeerConnectionStateConnecting:
          _setStatus(
            'Connecting...',
          );
          break;

        case RTCPeerConnectionState
            .RTCPeerConnectionStateFailed:
          _setStatus(
            'Call failed',
          );
          break;

        case RTCPeerConnectionState
            .RTCPeerConnectionStateDisconnected:
          _setStatus(
            'Disconnected',
          );
          break;

        default:
          break;
      }
    };

    _peerConnection!.onTrack =
        (
        RTCTrackEvent event,
        ) {
      if (event.track.kind ==
          'audio') {
        _setStatus(
          'Connected',
        );
      }
    };
  }

  //===============================
  // OUTGOING CALL
  //===============================

  Future<void>
  _startOutgoingCall() async {
    final String? callerId =
        _auth.currentUser?.uid;

    if (callerId == null ||
        callerId.isEmpty) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final DocumentReference<
        Map<String, dynamic>>
    callReference =
    _firestore
        .collection(
      'calls',
    )
        .doc();

    _callId =
        callReference.id;

    _peerConnection!
        .onIceCandidate =
        (
        RTCIceCandidate candidate,
        ) {
      if (candidate.candidate ==
          null ||
          candidate.candidate!
              .isEmpty) {
        return;
      }

      callReference
          .collection(
        'callerCandidates',
      )
          .add(
        <String, dynamic>{
          'candidate':
          candidate.candidate,

          'sdpMid':
          candidate.sdpMid,

          'sdpMLineIndex':
          candidate
              .sdpMLineIndex,

          'createdAt':
          FieldValue
              .serverTimestamp(),
        },
      );
    };

    final RTCSessionDescription offer =
    await _peerConnection!
        .createOffer(
      <String, dynamic>{
        'offerToReceiveAudio':
        1,

        'offerToReceiveVideo':
        0,
      },
    );

    await _peerConnection!
        .setLocalDescription(
      offer,
    );

    await callReference.set(
      <String, dynamic>{
        'callId':
        _callId,

        'callerId':
        callerId,

        'calleeId':
        widget.otherUserId,

        'type':
        'audio',

        'status':
        'ringing',

        'offer':
        <String, dynamic>{
          'type':
          offer.type,

          'sdp':
          offer.sdp,
        },

        'createdAt':
        FieldValue
            .serverTimestamp(),

        'updatedAt':
        FieldValue
            .serverTimestamp(),
      },
    );

    _setStatus(
      'Calling...',
    );

    _listenToCallDocument(
      callReference,
    );

    _listenToRemoteCandidates(
      callReference.collection(
        'calleeCandidates',
      ),
    );
  }

  //===============================
  // ANSWER CALL
  //===============================

  Future<void>
  _answerIncomingCall() async {
    final String incomingCallId =
        widget.callId?.trim() ??
            '';

    if (incomingCallId.isEmpty) {
      throw Exception(
        'Invalid call.',
      );
    }

    _callId =
        incomingCallId;

    final DocumentReference<
        Map<String, dynamic>>
    callReference =
    _firestore
        .collection(
      'calls',
    )
        .doc(
      _callId,
    );

    final DocumentSnapshot<
        Map<String, dynamic>>
    snapshot =
    await callReference.get();

    if (!snapshot.exists) {
      throw Exception(
        'This call no longer exists.',
      );
    }

    final Map<String, dynamic>
    data =
        snapshot.data() ??
            <String, dynamic>{};

    final Map<String, dynamic>
    offer =
    Map<String, dynamic>.from(
      data['offer'] is Map
          ? data['offer'] as Map
          : <String, dynamic>{},
    );

    if ((offer['sdp'] ?? '')
        .toString()
        .isEmpty) {
      throw Exception(
        'The incoming call has no valid offer.',
      );
    }

    _peerConnection!
        .onIceCandidate =
        (
        RTCIceCandidate candidate,
        ) {
      if (candidate.candidate ==
          null ||
          candidate.candidate!
              .isEmpty) {
        return;
      }

      callReference
          .collection(
        'calleeCandidates',
      )
          .add(
        <String, dynamic>{
          'candidate':
          candidate.candidate,

          'sdpMid':
          candidate.sdpMid,

          'sdpMLineIndex':
          candidate
              .sdpMLineIndex,

          'createdAt':
          FieldValue
              .serverTimestamp(),
        },
      );
    };

    await _peerConnection!
        .setRemoteDescription(
      RTCSessionDescription(
        offer['sdp']
            ?.toString(),

        offer['type']
            ?.toString(),
      ),
    );

    _remoteDescriptionSet =
    true;

    final RTCSessionDescription answer =
    await _peerConnection!
        .createAnswer(
      <String, dynamic>{
        'offerToReceiveAudio':
        1,

        'offerToReceiveVideo':
        0,
      },
    );

    await _peerConnection!
        .setLocalDescription(
      answer,
    );

    await callReference.update(
      <String, dynamic>{
        'answer':
        <String, dynamic>{
          'type':
          answer.type,

          'sdp':
          answer.sdp,
        },

        'status':
        'active',

        'answeredAt':
        FieldValue
            .serverTimestamp(),

        'updatedAt':
        FieldValue
            .serverTimestamp(),
      },
    );

    _setStatus(
      'Connecting...',
    );

    _listenToCallDocument(
      callReference,
    );

    _listenToRemoteCandidates(
      callReference.collection(
        'callerCandidates',
      ),
    );
  }

  //===============================
  // CALL LISTENER
  //===============================

  void _listenToCallDocument(
      DocumentReference<
          Map<String, dynamic>>
      callReference,
      ) {
    _callSubscription
        ?.cancel();

    _callSubscription =
        callReference
            .snapshots()
            .listen(
              (
              DocumentSnapshot<
                  Map<String, dynamic>>
              snapshot,
              ) async {
            if (!snapshot.exists) {
              return;
            }

            final Map<String, dynamic>
            data =
                snapshot.data() ??
                    <String, dynamic>{};

            final String status =
            (data['status'] ?? '')
                .toString();

            if (!widget.incoming &&
                !_remoteDescriptionSet &&
                data['answer'] is Map) {
              final Map<String, dynamic>
              answer =
              Map<String, dynamic>
                  .from(
                data['answer'] as Map,
              );

              if ((answer['sdp'] ?? '')
                  .toString()
                  .isNotEmpty) {
                await _peerConnection
                    ?.setRemoteDescription(
                  RTCSessionDescription(
                    answer['sdp']
                        ?.toString(),

                    answer['type']
                        ?.toString(),
                  ),
                );

                _remoteDescriptionSet =
                true;

                _setStatus(
                  'Connecting...',
                );
              }
            }

            if (status ==
                'declined') {
              _setStatus(
                'Call declined',
              );

              await Future<void>.delayed(
                const Duration(
                  milliseconds:
                  700,
                ),
              );

              await _finishLocally();
            }

            if (status == 'ended' ||
                status == 'missed') {
              _setStatus(
                status == 'missed'
                    ? 'Missed call'
                    : 'Call ended',
              );

              await Future<void>.delayed(
                const Duration(
                  milliseconds:
                  500,
                ),
              );

              await _finishLocally();
            }
          },
        );
  }

  //===============================
  // ICE CANDIDATES
  //===============================

  void _listenToRemoteCandidates(
      CollectionReference<
          Map<String, dynamic>>
      candidates,
      ) {
    _candidateSubscription
        ?.cancel();

    _candidateSubscription =
        candidates
            .snapshots()
            .listen(
              (
              QuerySnapshot<
                  Map<String, dynamic>>
              snapshot,
              ) {
            for (final DocumentChange<
                Map<String, dynamic>>
            change
            in snapshot.docChanges) {
              if (change.type !=
                  DocumentChangeType
                      .added) {
                continue;
              }

              final Map<String, dynamic>
              data =
                  change.doc.data() ??
                      <String, dynamic>{};

              final String candidate =
              (data['candidate'] ??
                  '')
                  .toString();

              if (candidate.isEmpty) {
                continue;
              }

              _peerConnection
                  ?.addCandidate(
                RTCIceCandidate(
                  candidate,

                  data['sdpMid']
                      ?.toString(),

                  data['sdpMLineIndex']
                  is int
                      ? data[
                  'sdpMLineIndex']
                  as int
                      : int.tryParse(
                    '${data['sdpMLineIndex']}',
                  ),
                ),
              );
            }
          },
        );
  }

  //===============================
  // MUTE
  //===============================

  void _toggleMute() {
    final List<MediaStreamTrack>
    tracks =
        _localStream
            ?.getAudioTracks() ??
            <MediaStreamTrack>[];

    setState(() {
      _muted =
      !_muted;
    });

    for (final MediaStreamTrack track
    in tracks) {
      track.enabled =
      !_muted;
    }
  }

  //===============================
  // SPEAKER
  //===============================

  Future<void>
  _toggleSpeaker() async {
    final bool value =
    !_speakerOn;

    try {
      await Helper
          .setSpeakerphoneOn(
        value,
      );
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      _speakerOn =
          value;
    });
  }

  //===============================
  // HANG UP
  //===============================

  Future<void> _hangUp() async {
    if (_ending) {
      return;
    }

    _ending =
    true;

    if (_callId.isNotEmpty) {
      try {
        await _firestore
            .collection(
          'calls',
        )
            .doc(
          _callId,
        )
            .set(
          <String, dynamic>{
            'status':
            'ended',

            'endedBy':
            _auth
                .currentUser
                ?.uid ??
                '',

            'endedAt':
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

    await _finishLocally();
  }

  //===============================
  // FINISH LOCALLY
  //===============================

  Future<void>
  _finishLocally() async {
    if (_finishedLocally) {
      return;
    }

    _finishedLocally =
    true;
    await _callSubscription
        ?.cancel();

    await _candidateSubscription
        ?.cancel();

    _callSubscription =
    null;

    _candidateSubscription =
    null;

    for (final MediaStreamTrack track
    in _localStream
        ?.getTracks() ??
        <MediaStreamTrack>[]) {
      track.stop();
    }

    await _localStream
        ?.dispose();

    _localStream =
    null;

    await _peerConnection
        ?.close();

    await _peerConnection
        ?.dispose();

    _peerConnection =
    null;
  //===============================
  // RETURN TO CONVERSATION
  //===============================

    if (mounted) {
      final NavigatorState navigator =
      Navigator.of(
        context,
      );

      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  //===============================
  // STATUS
  //===============================

  void _setStatus(
      String value,
      ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _statusText =
          value;
    });
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    return PopScope(
      canPop:
      false,

      onPopInvokedWithResult:
          (
          bool didPop,
          Object? result,
          ) async {
        if (!didPop) {
          await _hangUp();
        }
      },

      child:
      Scaffold(
        backgroundColor:
        const Color(
          0xFF081017,
        ),

        body:
        SafeArea(
          child:
          Column(
            children:
            <Widget>[
              const SizedBox(
                height:
                70,
              ),

              CircleAvatar(
                radius:
                58,

                backgroundColor:
                Colors.white10,

                backgroundImage:
                widget
                    .otherPhotoUrl
                    .trim()
                    .isNotEmpty
                    ? NetworkImage(
                  widget
                      .otherPhotoUrl,
                )
                    : null,

                child:
                widget
                    .otherPhotoUrl
                    .trim()
                    .isEmpty
                    ? const Icon(
                  Icons
                      .person_rounded,
                  size:
                  58,
                  color:
                  Colors.white70,
                )
                    : null,
              ),

              const SizedBox(
                height:
                20,
              ),

              Text(
                widget.otherName,
                textAlign:
                TextAlign.center,
                style:
                const TextStyle(
                  color:
                  Colors.white,
                  fontSize:
                  25,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              const SizedBox(
                height:
                8,
              ),

              Text(
                _statusText,
                style:
                const TextStyle(
                  color:
                  Colors.white60,
                  fontSize:
                  14,
                ),
              ),

              const Spacer(),

              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceEvenly,
                children:
                <Widget>[
                  _CallActionButton(
                    icon:
                    _muted
                        ? Icons
                        .mic_off_rounded
                        : Icons
                        .mic_rounded,

                    label:
                    _muted
                        ? 'Unmute'
                        : 'Mute',

                    onTap:
                    _toggleMute,
                  ),

                  _CallActionButton(
                    icon:
                    _speakerOn
                        ? Icons
                        .volume_up_rounded
                        : Icons
                        .volume_down_rounded,

                    label:
                    'Speaker',

                    active:
                    _speakerOn,

                    onTap:
                    _toggleSpeaker,
                  ),
                ],
              ),

              const SizedBox(
                height:
                34,
              ),

              GestureDetector(
                onTap:
                _hangUp,

                child:
                Container(
                  width:
                  72,

                  height:
                  72,

                  decoration:
                  const BoxDecoration(
                    color:
                    Colors.redAccent,
                    shape:
                    BoxShape.circle,
                  ),

                  child:
                  const Icon(
                    Icons
                        .call_end_rounded,
                    color:
                    Colors.white,
                    size:
                    34,
                  ),
                ),
              ),

              const SizedBox(
                height:
                56,
              ),
            ],
          ),
        ),
      ),
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _callSubscription
        ?.cancel();

    _candidateSubscription
        ?.cancel();

    for (final MediaStreamTrack track
    in _localStream
        ?.getTracks() ??
        <MediaStreamTrack>[]) {
      track.stop();
    }

    _localStream
        ?.dispose();

    _peerConnection
        ?.close();

    _peerConnection
        ?.dispose();

    super.dispose();
  }
}

//===============================
// CALL ACTION BUTTON
//===============================

class _CallActionButton
    extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;

  final String label;

  final VoidCallback onTap;

  final bool active;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children:
      <Widget>[
        Material(
          color:
          active
              ? const Color(
            0xFF29B6F6,
          )
              : Colors.white12,
          shape:
          const CircleBorder(),
          child:
          InkWell(
            customBorder:
            const CircleBorder(),
            onTap:
            onTap,
            child:
            SizedBox(
              width:
              62,
              height:
              62,
              child:
              Icon(
                icon,
                color:
                Colors.white,
                size:
                27,
              ),
            ),
          ),
        ),

        const SizedBox(
          height:
          8,
        ),

        Text(
          label,
          style:
          const TextStyle(
            color:
            Colors.white70,
            fontSize:
            12,
          ),
        ),
      ],
    );
  }
}
