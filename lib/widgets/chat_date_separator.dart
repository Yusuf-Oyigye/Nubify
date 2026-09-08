import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

//===============================
// CHAT DATE SEPARATOR
//===============================

class ChatDateSeparator
    extends StatelessWidget {
  const ChatDateSeparator({
    super.key,
    required this.date,
  });

  final DateTime date;

  //===============================
  // LABEL
  //===============================

  String _label() {
    final DateTime now =
    DateTime.now();

    final DateTime today =
    DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime messageDate =
    DateTime(
      date.year,
      date.month,
      date.day,
    );

    final int difference =
        today
            .difference(
          messageDate,
        )
            .inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    return DateFormat(
      'dd/MM/yyyy',
    ).format(
      date,
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical:
        12,
      ),
      child:
      Center(
        child:
        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal:
            13,
            vertical:
            6,
          ),
          decoration:
          BoxDecoration(
            color:
            const Color(
              0xFF18232B,
            ),
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            border:
            Border.all(
              color:
              Colors.white10,
            ),
          ),
          child:
          Text(
            _label(),
            style:
            const TextStyle(
              color:
              Colors.white70,
              fontSize:
              11,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}