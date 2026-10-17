import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/nubify_link_router.dart';
import '../utils/link_detector.dart';

//===================================================
// AUTH-AWARE NUBIFY DEEP LINK GATE
//===================================================

class NubifyDeepLinkGate extends StatefulWidget {
  const NubifyDeepLinkGate({super.key, required this.child});

  final Widget child;

  @override
  State<NubifyDeepLinkGate> createState() => _NubifyDeepLinkGateState();
}

class _NubifyDeepLinkGateState extends State<NubifyDeepLinkGate> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<User?>? _authSubscription;
  Uri? _pendingUri;
  String _lastOpenedUrl = '';
  bool _initialHandled = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user != null && _pendingUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
      }
    });
    _linkSubscription = _appLinks.uriLinkStream.listen(_queueOrOpen);

    if (_initialHandled) {
      return;
    }
    _initialHandled = true;
    try {
      final Uri? initial = await _appLinks.getInitialLink();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _queueOrOpen(initial),
        );
      }
    } catch (_) {
      // A malformed platform link must never block normal app startup.
    }
  }

  Future<void> _queueOrOpen(Uri uri) async {
    if (!mounted) {
      return;
    }
    final String value = uri.toString();
    if (!LinkDetector.isNubifyUrl(value) ||
        value == _lastOpenedUrl ||
        value == _pendingUri?.toString()) {
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      _pendingUri = uri;
      return;
    }
    await _open(uri);
  }

  Future<void> _openPending() async {
    final Uri? pending = _pendingUri;
    if (pending == null || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    await _open(pending);
  }

  Future<void> _open(Uri uri) async {
    if (!mounted || _opening) {
      _pendingUri = uri;
      return;
    }
    _opening = true;
    _pendingUri = null;
    _lastOpenedUrl = uri.toString();
    try {
      await NubifyLinkRouter.open(context, uri.toString());
    } finally {
      _opening = false;
      if (_pendingUri != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
