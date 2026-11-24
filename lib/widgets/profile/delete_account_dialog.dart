import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/profile/account_deletion_service.dart';
import '../menu/nubify_menu_components.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// STEP 1 — "ARE YOU SURE?" (YES / NO)
//===================================================

Future<void> confirmDeleteAccount(BuildContext context) async {
  final bool? sure = await showDialog<bool>(
    context: context,

    builder: (dialogContext) => AlertDialog(
      backgroundColor: NubifyMenuColors.surface(dialogContext),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: NubifyPalette.crimson),

          SizedBox(width: 12),

          Expanded(child: Text(context.tr('Delete Account?'))),
        ],
      ),

      content: Text(context.tr('Are you sure you want to delete your account? '
            'Your profile will be permanently removed and this cannot be undone.'),
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),

          child: Text(context.tr('No')),
        ),

        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NubifyPalette.crimson,
            foregroundColor: Colors.white,
          ),

          onPressed: () => Navigator.pop(dialogContext, true),

          child: Text(context.tr('Yes')),
        ),
      ],
    ),
  );

  // "No", or tapped outside the dialog -> stop here.
  if (sure != true || !context.mounted) return;

  //===================================================
  // STEP 2 — CONFIRM PASSWORD, THEN DELETE
  //===================================================

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountPasswordDialog(),
  );
}

//===================================================
// PASSWORD DIALOG
//===================================================

class _DeleteAccountPasswordDialog extends StatefulWidget {
  const _DeleteAccountPasswordDialog();

  @override
  State<_DeleteAccountPasswordDialog> createState() =>
      _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState
    extends State<_DeleteAccountPasswordDialog> {
  final TextEditingController _password = TextEditingController();

  bool _deleting = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  //===================================================
  // DELETE BUTTON PRESSED
  //===================================================

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = context.tr('Please enter your password.'));
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await AccountDeletionService().deleteAccount(password: _password.text);

      // Success: main.dart now shows the LoginScreen.
      if (mounted) Navigator.of(context).pop();
    }
    //===================================================
    // WRONG PASSWORD / FIREBASE LOGIN ERRORS
    //===================================================
    on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _deleting = false;

        _error = switch (error.code) {
          'wrong-password' ||
          'invalid-credential' => context.tr('Incorrect password. Please try again.'),
          'too-many-requests' =>
          context.tr('Too many attempts. Please wait a moment and retry.'),
          'network-request-failed' => context.tr('No internet connection. Please retry.'),
          _ => error.message ?? context.tr('Could not delete your account. Please retry.'),
        };
      });
    }
    //===================================================
    // ANY OTHER ERROR
    //===================================================
    catch (_) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
        _error =
        context.tr('Could not delete your account. Check your connection and retry.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NubifyMenuColors.surface(context),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

      title: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: NubifyPalette.crimson),

          SizedBox(width: 12),

          Expanded(child: Text(context.tr('Confirm Password'))),
        ],
      ),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(context.tr('For your security, enter your password to permanently '
                'delete your account.'),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _password,
            obscureText: _hidePassword,
            enabled: !_deleting,
            autofocus: true,
            onSubmitted: (_) => _delete(),

            decoration: InputDecoration(
              labelText: context.tr('Password'),
              errorText: _error,
              errorMaxLines: 3,

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),

              suffixIcon: IconButton(
                onPressed: () => setState(() => _hidePassword = !_hidePassword),

                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ],
      ),

      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),

          child: Text(context.tr('Cancel')),
        ),

        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NubifyPalette.crimson,
            foregroundColor: Colors.white,
            disabledBackgroundColor: NubifyPalette.crimson.withValues(
              alpha: .6,
            ),
          ),

          onPressed: _deleting ? null : _delete,

          child: _deleting
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
              : Text(context.tr('Delete')),
        ),
      ],
    );
  }
}