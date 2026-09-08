import 'package:flutter/material.dart';

//===================================================
// PROFILE NAVIGATION
//===================================================

Future<void> openUserProfile(
    BuildContext context,
    String uid,
    ) async {
  final String cleanUid =
  uid.trim();

  if (cleanUid.isEmpty) {
    return;
  }

  await Navigator.of(
    context,
  ).pushNamed(
    '/profile',
    arguments:
    cleanUid,
  );
}

//===================================================
// RETURN TO HOME
//===================================================

void returnToNubifyHome(
    BuildContext context,
    ) {
  Navigator.of(
    context,
  ).pushNamedAndRemoveUntil(
    '/home',
        (_) => false,
  );
}