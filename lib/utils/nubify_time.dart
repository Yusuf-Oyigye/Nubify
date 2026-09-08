import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ====
// NUBIFY TIME
// ====

class NubifyTime {
  const NubifyTime._();

  // ====
  // FORMAT FIRESTORE TIMESTAMP
  // ====

  static String formatTimestamp(
      Timestamp? timestamp,
      ) {
    if (timestamp == null) {
      return '';
    }

    return formatDateTime(
      timestamp.toDate(),
    );
  }

  // ====
  // FORMAT DATE AND TIME
  // ====

  static String formatDateTime(
      DateTime? value,
      ) {
    if (value == null) {
      return '';
    }

    final DateTime date =
    value.toLocal();

    Duration difference =
    DateTime.now().difference(
      date,
    );

    // ====
// JUST NOW
// ====

    final int minutes =
        difference.inMinutes;

    if (minutes < 1) {
      return 'Just now';
    }

// ====
// MINUTES
// ====

    if (minutes < 60) {
      return '${minutes}m ago';
    }

// ====
// HOURS
// ====

    final int hours =
        difference.inHours;

    if (hours < 24) {
      return '${hours}h ago';
    }

// ====
// DAYS
// ====

    final int days =
        difference.inDays;

    if (days < 7) {
      return '${days}d ago';
    }

    return _absoluteDateTime(
      date,
    );
  }

  // ====
  // DATE AFTER 7 DAYS
  // ====

  static String _absoluteDateTime(
      DateTime date,
      ) {
    final String day =
    date.day
        .toString()
        .padLeft(
      2,
      '0',
    );

    final String month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    final String year =
    date.year.toString();

    final int hour12 =
    date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final String minute =
    date.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    final String period =
    date.hour >= 12
        ? 'PM'
        : 'AM';

    return '$day/$month/$year • $hour12:$minute $period';
  }

  // ====
  // LIVE REFRESH SPEED
  // ====

  static Duration refreshDelay(
      DateTime? value,
      ) {
    if (value == null) {
      return const Duration(
        minutes: 1,
      );
    }

    Duration difference =
    DateTime.now().difference(
      value.toLocal(),
    );

    if (difference.isNegative) {
      difference = Duration.zero;
    }

    if (difference.inMinutes < 1) {
      return const Duration(
        seconds: 1,
      );
    }

    if (difference.inHours < 1) {
      return const Duration(
        seconds: 20,
      );
    }

    if (difference.inDays < 1) {
      return const Duration(
        minutes: 1,
      );
    }

    if (difference.inDays < 7) {
      return const Duration(
        minutes: 30,
      );
    }

    return const Duration(
      hours: 12,
    );
  }
}

// ====
// LIVE TIME TEXT
// ====

class NubifyTimeText
    extends StatefulWidget {
  final DateTime? dateTime;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const NubifyTimeText({
    super.key,
    required this.dateTime,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  // ====
  // CREATE FROM FIRESTORE TIMESTAMP
  // ====

  factory NubifyTimeText.fromTimestamp({
    Key? key,
    required Timestamp? timestamp,
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return NubifyTimeText(
      key: key,
      dateTime:
      timestamp?.toDate(),
      style:
      style,
      textAlign:
      textAlign,
      maxLines:
      maxLines,
      overflow:
      overflow,
    );
  }

  @override
  State<NubifyTimeText>
  createState() =>
      _NubifyTimeTextState();
}

// ====
// LIVE TIME STATE
// ====

class _NubifyTimeTextState
    extends State<NubifyTimeText> {
  Timer? _timer;

  // ====
  // INIT
  // ====

  @override
  void initState() {
    super.initState();

    _scheduleRefresh();
  }

  // ====
  // UPDATE DATE
  // ====

  @override
  void didUpdateWidget(
      covariant NubifyTimeText oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.dateTime !=
        widget.dateTime) {
      _timer?.cancel();

      _scheduleRefresh();
    }
  }

  // ====
  // SCHEDULE LIVE REFRESH
  // ====

  void _scheduleRefresh() {
    if (widget.dateTime == null) {
      return;
    }

    _timer?.cancel();

    _timer = Timer(
      NubifyTime.refreshDelay(
        widget.dateTime,
      ),
          () {
        if (!mounted) {
          return;
        }

        setState(() {});

        _scheduleRefresh();
      },
    );
  }

  // ====
  // DISPOSE
  // ====

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  // ====
  // BUILD
  // ====

  @override
  Widget build(
      BuildContext context,
      ) {
    final String text =
    NubifyTime.formatDateTime(
      widget.dateTime,
    );

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      text,
      style:
      widget.style,
      textAlign:
      widget.textAlign,
      maxLines:
      widget.maxLines,
      overflow:
      widget.overflow,
    );
  }
}