import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/profile/username_service.dart';
import '../../utils/profile/username_rules.dart';

//===================================================
// USERNAME FIELD
//
// "@" is shown in front, so people never type it. As
// they type, the rules are checked straight away and,
// once valid, whether the name is free (after a short
// pause). Used by signup and Edit Profile.
//===================================================

class UsernameField extends StatefulWidget {
  const UsernameField({
    super.key,
    required this.controller,
    this.currentUid,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.translate,
  });

  final TextEditingController controller;

  /// The signed-in user, so their own name counts as free.
  final String? currentUid;

  /// The latest result, e.g. to block "Next" while taken.
  final ValueChanged<UsernameCheck>? onChanged;

  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Shows the label and messages in another language
  /// (signup). English when null.
  final String Function(String english)? translate;

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  late final UsernameService _service = UsernameService();

  Timer? _debounce;
  int _request = 0;
  UsernameCheck _status = UsernameCheck.empty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);

    // Check text that is already there (e.g. coming back to
    // this step) once the first frame is built.
    if (widget.controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onTextChanged();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _set(UsernameCheck status) {
    if (!mounted) return;
    setState(() => _status = status);
    widget.onChanged?.call(status);
  }

  void _onTextChanged() {
    final String text = widget.controller.text;

    // "@" is added by the app; drop it if pasted or typed.
    if (text.startsWith('@')) {
      final String cleaned = UsernameRules.clean(text);
      widget.controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
      return;
    }

    _debounce?.cancel();
    final int request = ++_request;

    if (text.trim().isEmpty) {
      _set(UsernameCheck.empty);
      return;
    }

    final String? error = UsernameRules.validate(text);
    if (error != null) {
      _set(UsernameCheck(UsernameStatus.invalid, error));
      return;
    }

    _set(const UsernameCheck(UsernameStatus.checking, 'Checking…'));

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final UsernameCheck result = await _service.check(
        text,
        currentUid: widget.currentUid,
      );
      if (request == _request) _set(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final (IconData? icon, Color color) = switch (_status.status) {
      UsernameStatus.available => (
        Icons.check_circle_rounded,
        const Color(0xFF22C55E),
      ),
      UsernameStatus.invalid ||
      UsernameStatus.taken => (Icons.error_rounded, const Color(0xFFFF5C6C)),
      UsernameStatus.checking => (null, scheme.onSurfaceVariant),
      UsernameStatus.unknown => (
        Icons.info_outline_rounded,
        scheme.onSurfaceVariant,
      ),
      UsernameStatus.empty => (null, scheme.onSurfaceVariant),
    };

    final String Function(String) tr =
        widget.translate ?? (String english) => english;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: widget.controller,
          // Usernames are English letters, even in Arabic.
          textDirection: TextDirection.ltr,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          autofillHints: const <String>[AutofillHints.newUsername],
          decoration: InputDecoration(
            labelText: tr('Username'),
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            prefixText: '@',
            suffixIcon: _status.status == UsernameStatus.checking
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : icon == null
                ? null
                : Icon(icon, color: color),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _status.message.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      tr(_status.message),
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
