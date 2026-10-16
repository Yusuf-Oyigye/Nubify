import 'package:flutter/material.dart';

//===================================================
// MEDIA ROUTE OBSERVER
//
// Media widgets subscribe to this observer so they know when another
// screen or modal is covering their route. This prevents hidden feed
// videos from continuing to play sound in the background.
//===================================================

final RouteObserver<ModalRoute<dynamic>> nubifyMediaRouteObserver =
RouteObserver<ModalRoute<dynamic>>();
