import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

//===================================================
// NUBIFY CALL STATUS DISPLAY
//===================================================

class NubifyCallDisplay {
  const NubifyCallDisplay._();

  static const Color blue = Color(0xFF29B6F6);
  static const Color red = Colors.redAccent;

  //===================================================
  // CALL STATUS
  //===================================================

  static String status(Map<String, dynamic> call) {
    return (call['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  static bool wasAnswered(Map<String, dynamic> call) {
    return call['answeredAt'] != null;
  }

  static bool isFinished(Map<String, dynamic> call) {
    return const <String>{
      'ended',
      'missed',
      'declined',
    }.contains(status(call));
  }

  //===================================================
  // DETECT MISSED CALL
  //===================================================

  static bool isMissedFor(
      Map<String, dynamic> call,
      String userId,
      ) {
    if (userId.isEmpty ||
        (call['calleeId'] ?? '').toString() != userId ||
        wasAnswered(call)) {
      return false;
    }

    return isFinished(call);
  }

  //===================================================
  // CALL LABEL
  //===================================================

  static String label(
      Map<String, dynamic> call,
      String userId,
      ) {
    final String callerId =
    (call['callerId'] ?? '').toString();

    final bool outgoing = callerId == userId;
    final String currentStatus = status(call);

    if (isMissedFor(call, userId)) {
      return currentStatus == 'declined'
          ? 'Declined audio call'
          : 'Missed audio call';
    }

    if (outgoing && currentStatus == 'declined') {
      return 'Call declined';
    }

    if (outgoing &&
        !wasAnswered(call) &&
        isFinished(call)) {
      return 'No answer';
    }

    if (currentStatus == 'ringing') {
      return outgoing
          ? 'Outgoing audio call'
          : 'Incoming audio call';
    }

    return outgoing
        ? 'Outgoing audio call'
        : 'Incoming audio call';
  }

  //===================================================
  // CALL ICON
  //===================================================

  static IconData icon(
      Map<String, dynamic> call,
      String userId,
      ) {
    if (isMissedFor(call, userId)) {
      return Icons.call_missed_rounded;
    }

    return (call['callerId'] ?? '').toString() == userId
        ? Icons.call_made_rounded
        : Icons.call_received_rounded;
  }

  //===================================================
  // CALL COLOR
  //===================================================

  static Color color(
      Map<String, dynamic> call,
      String userId,
      ) {
    return isMissedFor(call, userId) ? red : blue;
  }

  //===================================================
  // CALL TIMESTAMP
  //===================================================

  static DateTime time(Map<String, dynamic> call) {
    final dynamic value =
        call['createdAt'] ??
            call['answeredAt'] ??
            call['endedAt'] ??
            call['updatedAt'];

    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  //===================================================
  // CALL DURATION
  //===================================================

  static String duration(Map<String, dynamic> call) {
    final dynamic answer = call['answeredAt'];
    final dynamic end = call['endedAt'];

    if (answer is! Timestamp || end is! Timestamp) {
      return '';
    }

    final int seconds = end
        .toDate()
        .difference(answer.toDate())
        .inSeconds;

    if (seconds < 0) {
      return '';
    }

    if (seconds < 60) {
      return '$seconds sec';
    }

    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;

    if (minutes < 60) {
      return '${minutes}m ${remainingSeconds}s';
    }

    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;

    return '${hours}h ${remainingMinutes}m';
  }
}