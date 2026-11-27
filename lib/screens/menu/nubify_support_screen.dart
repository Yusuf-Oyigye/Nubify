import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../utils/common/nubify_contact.dart';
import '../../widgets/menu/nubify_menu_components.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// NUBIFY SUPPORT
//
// Contact Support lets the student pick WhatsApp (fast)
// or Gmail (slower). Report a Problem and Suggest a
// Feature use WhatsApp only. Each comes with a
// ready-made message that suits it.
//===================================================

class NubifySupportScreen extends StatelessWidget {
  const NubifySupportScreen({super.key});

  static const Color _whatsappGreen = Color(0xFF25D366);
  static const Color _gmailRed = Color(0xFFEA4335);

  //===================================================
  // READY-MADE MESSAGES
  //===================================================

  static const String _supportMessage =
      'Hello Digitaldoc 👋\n\n'
      'I need help with Nubify.\n\n'
      'My Nubify username: @\n'
      'What I need help with: ';

  static const String _problemMessage =
      'Hello Digitaldoc 👋\n\n'
      'I want to report a problem on Nubify.\n\n'
      'My Nubify username: @\n'
      'Where it happened (screen/feature): \n'
      'What happened: \n'
      'My phone model: \n\n'
      '(I can send a screenshot too.)';

  static const String _ideaMessage =
      'Hello Digitaldoc 👋\n\n'
      'I have an idea to make Nubify better.\n\n'
      'My Nubify username: @\n'
      'My idea: \n'
      'Why it would help students: ';

  //===================================================
  // ACTIONS
  //===================================================

  Future<void> _open(BuildContext context, Uri uri, String app) async {
    final bool opened = await NubifyContact.open(uri);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Could not open {app} on this phone.', {'app': app}))),
      );
    }
  }

  // [subject] adds the Gmail option (Contact Support
  // only); without it the sheet offers WhatsApp alone.
  Future<void> _chooseApp(
    BuildContext context, {
    required String message,
    String? subject,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: NubifyMenuColors.surface(context),
      builder: (BuildContext sheetContext) {
        Widget option({
          required Widget logo,
          required Color color,
          required String title,
          required String subtitle,
          required String detail,
          required VoidCallback onTap,
        }) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: logo),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: NubifyMenuColors.primaryText(context),
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              '$subtitle\n$detail',
              style: TextStyle(color: NubifyMenuColors.secondaryText(context)),
            ),
            isThreeLine: true,
            trailing: Icon(
              Icons.open_in_new_rounded,
              color: NubifyMenuColors.secondaryText(context),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  context.tr('How would you like to reach us?'),
                  style: TextStyle(
                    color: NubifyMenuColors.primaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              option(
                logo: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Colors.white,
                  size: 24,
                ),
                color: _whatsappGreen,
                title: context.tr('WhatsApp'),
                subtitle: context.tr('Fastest response'),
                detail: NubifyContact.whatsappDisplay,
                onTap: () =>
                    _open(context, NubifyContact.whatsapp(message), 'WhatsApp'),
              ),
              if (subject != null)
                option(
                logo: const Icon(
                  Icons.mail_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                color: _gmailRed,
                title: context.tr('Gmail'),
                subtitle: context.tr('Replies may take a little longer'),
                detail: NubifyContact.email,
                onTap: () => _open(
                  context,
                  NubifyContact.gmail(subject: subject, body: message),
                  context.tr('your email app'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return NubifyMenuPage(
      title: context.tr('Support'),
      subtitle: context.tr('Help, problems and ideas.'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 10, 10),
        decoration: BoxDecoration(
          color: NubifyMenuColors.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NubifyMenuColors.stroke(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            //=========================================
            // HEADER
            //=========================================
            Row(
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: NubifyMenuColors.tint(context, nubifySky),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.headset_mic_outlined,
                    color: nubifySky,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.tr('Nubify Support'),
                        style: TextStyle(
                          color: NubifyMenuColors.primaryText(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr("We're here to help you."),
                        style: TextStyle(
                          color: NubifyMenuColors.secondaryText(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 6, 6),
              child: Divider(color: NubifyMenuColors.stroke(context)),
            ),

            //=========================================
            // OPTIONS
            //=========================================
            _SupportRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: context.tr('Contact Support'),
              subtitle: context.tr(
                'For a fast response, chat with me on WhatsApp. You can also email me.',
              ),
              onTap: () => _chooseApp(
                context,
                message: _supportMessage,
                subject: 'Nubify support request',
              ),
            ),
            _SupportRow(
              icon: Icons.bug_report_outlined,
              title: context.tr('Report a Problem'),
              subtitle: context.tr('Report bugs or technical issues.'),
              onTap: () => _chooseApp(context, message: _problemMessage),
            ),
            _SupportRow(
              icon: Icons.lightbulb_outline_rounded,
              title: context.tr('Suggest a Feature'),
              subtitle: context.tr('Share ideas to improve Nubify.'),
              onTap: () => _chooseApp(context, message: _ideaMessage),
            ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// SUPPORT ROW
//===================================================

class _SupportRow extends StatelessWidget {
  const _SupportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, color: nubifySky, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: NubifyMenuColors.primaryText(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: NubifyMenuColors.secondaryText(context),
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: NubifyMenuColors.secondaryText(context),
            ),
          ],
        ),
      ),
    );
  }
}
