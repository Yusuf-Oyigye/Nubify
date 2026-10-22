import 'package:flutter/material.dart';

import '../services/profile_service.dart';

//===============================
// REPORT USER DIALOG
//===============================

Future<void> showReportUserDialog({
  required BuildContext context,
  required String targetUid,
}) async {
  final ProfileService service =
  ProfileService();

  String reason =
      'Spam';

  String details =
      '';

  final bool? submit =
  await showDialog<bool>(
    context:
    context,

    builder:
        (
        BuildContext dialogContext,
        ) {
      return StatefulBuilder(
        builder:
            (
            BuildContext context,
            void Function(
                void Function(),
                ) setDialogState,
            ) {
          return AlertDialog(
            title:
            const Text(
              'Report user',
            ),

            content:
            SingleChildScrollView(
              child:
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }

                  setDialogState(() {
                    reason = value;
                  });
                },
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,

                  children:
                  <Widget>[
                  ...<String>[
                    'Spam',
                    'Harassment',
                    'Scam or fraud',
                    'Inappropriate content',
                    'Impersonation',
                    'Other',
                  ].map(
                        (
                        String item,
                        ) =>
                        RadioListTile<String>(
                          value:
                          item,

                          contentPadding:
                          EdgeInsets.zero,

                          title:
                          Text(
                            item,
                          ),
                        ),
                  ),

                  const SizedBox(
                    height:
                    8,
                  ),

                  TextField(
                    minLines:
                    2,

                    maxLines:
                    5,

                    maxLength:
                    500,

                    onChanged:
                        (
                        String value,
                        ) {
                      details =
                          value.trim();
                    },

                    decoration:
                    const InputDecoration(
                      labelText:
                      'Tell us more (optional)',

                      hintText:
                      'Explain what happened...',

                      border:
                      OutlineInputBorder(),
                    ),
                  ),
                  ],
                ),
              ),
            ),

            actions:
            <Widget>[
              TextButton(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },

                child:
                const Text(
                  'Cancel',
                ),
              ),

              FilledButton(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },

                child:
                const Text(
                  'Report',
                ),
              ),
            ],
          );
        },
      );
    },
  );

  if (submit !=
      true) {
    return;
  }

  await service.reportUser(
    targetUid:
    targetUid,

    reason:
    reason,

    details:
    details,
  );

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(
    const SnackBar(
      content:
      Text(
        'Report submitted.',
      ),
    ),
  );
}
