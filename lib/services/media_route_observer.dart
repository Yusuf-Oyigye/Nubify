// The observer was originally placed in widgets, while the app, video player,
// and tests import it from services. Re-export the single existing instance so
// every caller shares one route observer and hidden videos pause correctly.
export '../widgets/media_route_observer.dart';
