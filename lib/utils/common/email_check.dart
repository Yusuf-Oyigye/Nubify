import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

//===================================================
// EMAIL CHECK
//
// Catches emails that cannot be real before an account
// is made:
// 1. format: must have "@" and a proper domain
// 2. common typos such as "gmial.com"
// 3. the domain must exist and accept mail (asks public
//    DNS for its mail servers; only the domain is sent)
// If the phone is offline, step 3 is skipped rather than
// blocking signup.
//===================================================

abstract final class EmailCheck {
  static final RegExp _format = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
    r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$',
  );

  static const Map<String, String> _typos = <String, String>{
    'gmial.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'yahooo.com': 'yahoo.com',
    'yaho.com': 'yahoo.com',
    'yahoo.con': 'yahoo.com',
    'hotmial.com': 'hotmail.com',
    'hotmai.com': 'hotmail.com',
    'hotmail.con': 'hotmail.com',
    'outlok.com': 'outlook.com',
    'outlook.con': 'outlook.com',
    'icloud.con': 'icloud.com',
  };

  // Big providers we never need to look up.
  static const Set<String> _knownDomains = <String>{
    'gmail.com',
    'googlemail.com',
    'yahoo.com',
    'hotmail.com',
    'outlook.com',
    'live.com',
    'icloud.com',
    'me.com',
    'msn.com',
    'aol.com',
    'proton.me',
    'protonmail.com',
  };

  /// A message when [email] is not a usable address, else null.
  static String? validateFormat(String email) {
    final String value = email.trim();

    if (value.isEmpty) return 'Please enter your email.';
    if (!value.contains('@')) return 'Your email must contain "@".';
    if ('@'.allMatches(value).length > 1 ||
        value.contains('..') ||
        value.contains(' ') ||
        !_format.hasMatch(value)) {
      return 'This email address does not look right. Please check it.';
    }

    final String domain = value.split('@').last.toLowerCase();
    final String? fix = _typos[domain];
    if (fix != null) {
      return 'Did you mean ${value.split('@').first}@$fix?';
    }

    return null;
  }

  /// A message when the email's domain cannot receive mail,
  /// else null. Returns null when the check cannot run.
  static Future<String?> validateDomain(String email) async {
    if (kIsWeb) return null;

    final String domain = email.trim().split('@').last.toLowerCase();
    if (_knownDomains.contains(domain)) return null;

    final Map<String, dynamic>? mx = await _lookup(domain, 'MX');
    if (mx == null) return null;

    // 3 = this domain does not exist.
    if (mx['Status'] == 3) {
      return 'We could not find "$domain". Please check your email.';
    }

    if (_hasAnswer(mx)) return null;

    // No mail servers listed: mail can still go to the
    // domain itself if it has an address.
    final Map<String, dynamic>? a = await _lookup(domain, 'A');
    if (a == null || _hasAnswer(a)) return null;

    return '"$domain" cannot receive email. Please use another address.';
  }

  static bool _hasAnswer(Map<String, dynamic> result) =>
      result['Status'] == 0 &&
      result['Answer'] is List &&
      (result['Answer'] as List).isNotEmpty;

  static Future<Map<String, dynamic>?> _lookup(
    String domain,
    String type,
  ) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);

    try {
      final HttpClientRequest request = await client.getUrl(
        Uri.https('dns.google', '/resolve', <String, String>{
          'name': domain,
          'type': type,
        }),
      );
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 6),
      );

      if (response.statusCode != 200) return null;

      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 6));
      final Object? decoded = jsonDecode(body);

      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (error) {
      debugPrint('Email domain check skipped: $error');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
