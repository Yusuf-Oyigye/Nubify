import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/services/media_route_observer.dart';

void main() {
  testWidgets(
    'media route observer reports when a screen covers and reveals the feed',
    (WidgetTester tester) async {
      final GlobalKey<_RouteAwareProbeState> probeKey =
          GlobalKey<_RouteAwareProbeState>();
      final GlobalKey<NavigatorState> navigatorKey =
          GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[nubifyMediaRouteObserver],
          home: _RouteAwareProbe(key: probeKey),
        ),
      );

      expect(probeKey.currentState!.coveredCount, 0);

      await tester.tap(find.text('Open story editor'));
      await tester.pumpAndSettle();

      expect(probeKey.currentState!.coveredCount, 1);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(probeKey.currentState!.revealedCount, 1);
    },
  );
}

class _RouteAwareProbe extends StatefulWidget {
  const _RouteAwareProbe({super.key});

  @override
  State<_RouteAwareProbe> createState() => _RouteAwareProbeState();
}

class _RouteAwareProbeState extends State<_RouteAwareProbe> with RouteAware {
  ModalRoute<dynamic>? _route;

  int coveredCount = 0;

  int revealedCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);

    if (currentRoute == _route) {
      return;
    }

    if (_route != null) {
      nubifyMediaRouteObserver.unsubscribe(this);
    }

    _route = currentRoute;

    if (currentRoute != null) {
      nubifyMediaRouteObserver.subscribe(this, currentRoute);
    }
  }

  @override
  void didPushNext() {
    coveredCount++;
  }

  @override
  void didPopNext() {
    revealedCount++;
  }

  @override
  void dispose() {
    nubifyMediaRouteObserver.unsubscribe(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  return const Scaffold(
                    body: Center(child: Text('Share post to story')),
                  );
                },
              ),
            );
          },
          child: const Text('Open story editor'),
        ),
      ),
    );
  }
}
