import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../services/nubify_link_router.dart';
import '../utils/link_detector.dart';

//===================================================
// NUBIFY DEEP LINK GATE
//===================================================

class NubifyDeepLinkGate
    extends StatefulWidget {
  const NubifyDeepLinkGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NubifyDeepLinkGate>
  createState() =>
      _NubifyDeepLinkGateState();
}

//===================================================
// NUBIFY DEEP LINK STATE
//===================================================

class _NubifyDeepLinkGateState
    extends State<NubifyDeepLinkGate> {
  final AppLinks _appLinks =
  AppLinks();

  StreamSubscription<Uri>?
  _subscription;

  String _lastUrl =
      '';

  bool _initialHandled =
  false;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _start();
  }

  //===================================================
  // START
  //===================================================

  Future<void> _start() async {
    if (!_initialHandled) {
      _initialHandled =
      true;

      try {
        final Uri? initial =
        await _appLinks
            .getInitialLink();

        if (initial !=
            null) {
          WidgetsBinding.instance
              .addPostFrameCallback(
                (_) {
              _handle(
                initial,
              );
            },
          );
        }
      } catch (_) {}
    }

    _subscription =
        _appLinks.uriLinkStream
            .listen(
              (
              Uri uri,
              ) {
            _handle(
              uri,
            );
          },
        );
  }

  //===================================================
  // HANDLE
  //===================================================

  Future<void> _handle(
      Uri uri,
      ) async {
    if (!mounted) {
      return;
    }

    final String value =
    uri.toString();

    if (value ==
        _lastUrl) {
      return;
    }

    if (!LinkDetector.isNubifyUrl(
      value,
    )) {
      return;
    }

    _lastUrl =
        value;

    await NubifyLinkRouter.open(
      context,
      value,
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return widget.child;
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _subscription?.cancel();

    super.dispose();
  }
}