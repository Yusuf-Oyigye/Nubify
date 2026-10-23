//===================================================
// STORY DRAWING DATA
//
// Coordinates are stored from 0.0 to 1.0 so a drawing keeps the same
// position on different phone sizes.
//===================================================

abstract final class StoryDrawingLimits {
  static const int maxStrokes = 80;
  static const int maxTotalPoints = 1600;
  static const int maxPointsPerStroke = 400;
}

class StoryDrawingPoint {
  const StoryDrawingPoint({required this.x, required this.y});

  final double x;
  final double y;

  factory StoryDrawingPoint.fromMap(Map<String, dynamic> map) {
    return StoryDrawingPoint(
      x: _safeDouble(map['x']).clamp(0.0, 1.0).toDouble(),
      y: _safeDouble(map['y']).clamp(0.0, 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{'x': x, 'y': y};

  static double _safeDouble(dynamic value) {
    return value is num ? value.toDouble() : 0.0;
  }
}

class StoryDrawingStroke {
  const StoryDrawingStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final int color;
  final double width;
  final List<StoryDrawingPoint> points;

  factory StoryDrawingStroke.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawPoints = map['points'] is List<dynamic>
        ? map['points'] as List<dynamic>
        : <dynamic>[];

    return StoryDrawingStroke(
      color: map['color'] is num ? (map['color'] as num).toInt() : 0xFFFFFFFF,
      width: (map['width'] is num ? (map['width'] as num).toDouble() : 5.0)
          .clamp(2.0, 24.0)
          .toDouble(),
      points: rawPoints
          .whereType<Map>()
          .take(StoryDrawingLimits.maxPointsPerStroke)
          .map(
            (Map<dynamic, dynamic> point) =>
                StoryDrawingPoint.fromMap(Map<String, dynamic>.from(point)),
          )
          .toList(growable: false),
    );
  }

  StoryDrawingStroke copyWith({List<StoryDrawingPoint>? points}) {
    return StoryDrawingStroke(
      color: color,
      width: width,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'color': color,
    'width': width,
    'points': points
        .take(StoryDrawingLimits.maxPointsPerStroke)
        .map((StoryDrawingPoint point) => point.toMap())
        .toList(growable: false),
  };
}
