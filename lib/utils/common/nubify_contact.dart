import 'package:url_launcher/url_launcher.dart';

//===================================================
// NUBIFY CONTACT
//
// The founder's WhatsApp and Gmail, used by the Support
// screen and About the Developer. Change them here only.
//===================================================

abstract final class NubifyContact {
  // International format without "+" (for wa.me links).
  static const String whatsappNumber = '2347043448420';
  static const String whatsappDisplay = '+234 704 344 8420';

  static const String email = 'yusufoyigye@gmail.com';

  /// Opens WhatsApp straight to the founder's chat, with
  /// [message] typed in and ready to send.
  static Uri whatsapp([String message = '']) => Uri.https(
    'wa.me',
    '/$whatsappNumber',
    message.isEmpty ? null : <String, String>{'text': message},
  );

  /// Opens the email app with the address, subject and body
  /// filled in.
  static Uri gmail({String subject = '', String body = ''}) => Uri(
    scheme: 'mailto',
    path: email,
    query: <String>[
      if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
      if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
    ].join('&'),
  );

  /// Opens [uri] in WhatsApp or the email app. False when
  /// nothing on the phone can open it.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
