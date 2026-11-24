import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/nubify_text.dart';

//===============================
// CHAT DATE SEPARATOR
//===============================

class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.date});

  final DateTime date;

  //===============================
  // LABEL
  //===============================

  String _label() {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime messageDate = DateTime(date.year, date.month, date.day);

    final int difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return NubifyText.tr('Today');
    }

    if (difference == 1) {
      return NubifyText.tr('Yesterday');
    }

    return DateFormat('dd/MM/yyyy').format(date);
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xFF1A2534).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : const Color(0xFFE1E8F2),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            _label(),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
