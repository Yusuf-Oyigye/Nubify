import 'package:flutter/material.dart';

import '../../services/profile/profile_service.dart';
import '../../l10n/nubify_text.dart';

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
            Text(context.tr('Report user'),
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
                            context.tr(item),
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
                    InputDecoration(
                      labelText:
                      context.tr('Tell us more (optional)'),

                      hintText:
                      context.tr('Explain what happened...'),

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
                Text(context.tr('Cancel'),
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
                Text(context.tr('Report'),
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
    SnackBar(
      content:
      Text(context.tr('Report submitted.'),
      ),
    ),
  );
}
