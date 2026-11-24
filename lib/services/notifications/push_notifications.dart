import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../common/language_preference.dart';

//===================================================
// PHONE NOTIFICATIONS
//
// Pop-ups on the phone screen and in the notification
// panel for likes, comments, replies, reposts, follows,
// tags, stories, Huddles, chats and groups.
//
// 1. Once signed in, asks "Allow notifications?".
// 2. Saves this phone's push address (FCM token) and
//    app language in pushTokens/{uid}. The server
//    (functions/push.js) sends every new notification
//    and chat message there, in that language.
// 3. While the app is open Android shows nothing by
//    itself, so the app shows the pop-up (but not for
//    the chat you are reading).
// 4. Tapping one opens the post, story, profile, chat
//    or group (NubifyPushGate).
//
// Every notification carries the Nubify name and logo
// (res/drawable/ic_stat_nubify, made from the signup
// logo by tool/icons/make_icons_test.dart).
//===================================================

class PushNotifications {
  PushNotifications._();

  static final PushNotifications instance = PushNotifications._();

  // Same id as the manifest default and functions/push.js.
  static const String channelId = 'nubify_alerts';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'Nubify notifications',
    description: 'Likes, comments, follows, chats and groups.',
    importance: Importance.high,
  );

  // Nubify blue (res/values/colors.xml nubify_notification).
  static const Color _blue = Color(0xFF1546C9);

  /// The chat or group on screen right now; its messages
  /// do not pop up.
  static String? openChatId;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _taps =
      StreamController<Map<String, dynamic>>.broadcast();

  /// The data of each notification the person taps.
  Stream<Map<String, dynamic>> get taps => _taps.stream;

  bool _prepared = false;
  bool _listening = false;
  bool _launchChecked = false;
  String? _token;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  //===================================================
  // START (signed in)
  //===================================================

  Future<void> start() async {
    if (!_supported || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    try {
      await _prepare();

      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      final NotificationSettings settings = await messaging
          .requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      // iPhone shows them itself while the app is open.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!_listening) {
        _listening = true;
        FirebaseMessaging.onMessage.listen(_showWhileOpen);
        FirebaseMessaging.onMessageOpenedApp.listen(
          (RemoteMessage message) => _taps.add(message.data),
        );
        messaging.onTokenRefresh.listen(_save);
        AppLanguage.code.addListener(_languageChanged);
      }

      final String? token = await messaging.getToken();
      if (token != null) {
        await _save(token);
      }
    } catch (error) {
      debugPrint('Phone notifications not started: $error');
    }
  }

  //===================================================
  // THE NOTIFICATION THAT OPENED THE APP
  //===================================================

  /// Once per app start: the data of the notification
  /// tapped to open the app, if any.
  Future<Map<String, dynamic>?> launchTap() async {
    if (!_supported || _launchChecked) {
      return null;
    }
    _launchChecked = true;

    try {
      final RemoteMessage? message = await FirebaseMessaging.instance
          .getInitialMessage();
      if (message != null) {
        return message.data;
      }

      final NotificationAppLaunchDetails? details = await _local
          .getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return _decode(details?.notificationResponse?.payload);
      }
    } catch (error) {
      debugPrint('Notification launch check failed: $error');
    }

    return null;
  }

  //===================================================
  // STOP (before signing out)
  //
  // The next person who signs in on this phone must not
  // get this person's notifications.
  //===================================================

  Future<void> stop() async {
    if (!_supported) {
      return;
    }

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final String? token = _token;
    _token = null;

    try {
      if (uid != null && token != null) {
        await FirebaseFirestore.instance
            .collection('pushTokens')
            .doc(uid)
            .update(<Object, Object?>{
              FieldPath(<String>['tokens', token]): FieldValue.delete(),
            });
      }

      // A fresh address next time; the server forgets
      // the old one on its next send.
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Phone notifications not stopped: $error');
    }
  }

  //===================================================
  // SETUP
  //===================================================

  Future<void> _prepare() async {
    if (_prepared) {
      return;
    }
    _prepared = true;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_nubify'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final Map<String, dynamic>? data = _decode(response.payload);
        if (data != null) {
          _taps.add(data);
        }
      },
    );

    // High importance = it pops up on the screen.
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  //===================================================
  // SAVE THIS PHONE
  //===================================================

  Future<void> _save(String token) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    _token = token;

    await FirebaseFirestore.instance
        .collection('pushTokens')
        .doc(uid)
        .set(<String, dynamic>{
          'tokens': <String, dynamic>{
            token: <String, dynamic>{
              'language': AppLanguage.code.value,
              'platform': defaultTargetPlatform.name,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // New notifications come in the new language.
  void _languageChanged() {
    final String? token = _token;
    if (token != null) {
      _save(token).catchError((Object error) {
        debugPrint('Notification language not saved: $error');
      });
    }
  }

  //===================================================
  // POP-UP WHILE THE APP IS OPEN (Android)
  //===================================================

  Future<void> _showWhileOpen(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final RemoteNotification? notification = message.notification;
    if (notification == null) {
      return;
    }

    final String chatId = (message.data['chatId'] ?? '').toString();
    if (chatId.isNotEmpty && chatId == openChatId) {
      return;
    }

    try {
      await _local.show(
        id: (message.messageId ?? '${DateTime.now()}').hashCode & 0x7fffffff,
        title: notification.title,
        body: notification.body,
        payload: jsonEncode(message.data),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: 'ic_stat_nubify',
            color: _blue,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(notification.body ?? ''),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Notification pop-up failed: $error');
    }
  }

  Map<String, dynamic>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final Object? data = jsonDecode(payload);
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }
}
