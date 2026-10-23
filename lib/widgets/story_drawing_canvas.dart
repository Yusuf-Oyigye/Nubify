import 'package:flutter/material.dart';

import '../models/story_drawing.dart';

//===================================================
// STORY FINGER-DRAWING LAYER
//===================================================

class StoryDrawingCanvas extends StatelessWidget {
  const StoryDrawingCanvas({
    super.key,
    required this.strokes,
    this.editing = false,
    this.color = 0xFFFFFFFF,
    this.strokeWidth = 5.0,
    this.onChanged,
  });

  final List<StoryDrawingStroke> strokes;
  final bool editing;
  final int color;
  final double strokeWidth;
  final ValueChanged<List<StoryDrawingStroke>>? onChanged;

  int get _pointCount => strokes.fold<int>(
    0,
    (int count, StoryDrawingStroke stroke) => count + stroke.points.length,
  );

  StoryDrawingPoint _normalised(Offset position, Size size) {
    return StoryDrawingPoint(
      x: (position.dx / size.width).clamp(0.0, 1.0).toDouble(),
      y: (position.dy / size.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  void _startStroke(DragStartDetails details, Size size) {
    if (!editing ||
        onChanged == null ||
        strokes.length >= StoryDrawingLimits.maxStrokes ||
        _pointCount >= StoryDrawingLimits.maxTotalPoints) {
      return;
    }

    strokes.add(
      StoryDrawingStroke(
        color: color,
        width: strokeWidth,
        points: <StoryDrawingPoint>[_normalised(details.localPosition, size)],
      ),
    );

    onChanged!(List<StoryDrawingStroke>.of(strokes));
  }

  void _continueStroke(DragUpdateDetails details, Size size) {
    if (!editing ||
        onChanged == null ||
        strokes.isEmpty ||
        _pointCount >= StoryDrawingLimits.maxTotalPoints) {
      return;
    }

    final StoryDrawingStroke current = strokes.last;
    final StoryDrawingPoint next = _normalised(details.localPosition, size);

    if (current.points.isNotEmpty) {
      final StoryDrawingPoint previous = current.points.last;
      final double dx = next.x - previous.x;
      final double dy = next.y - previous.y;

      // Avoid saving hundreds of virtually identical touch samples.
      if ((dx * dx) + (dy * dy) < 0.000006) {
        return;
      }
    }

    current.points.add(next);
    onChanged!(List<StoryDrawingStroke>.of(strokes));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final Widget painting = CustomPaint(
          painter: StoryDrawingPainter(strokes),
          size: size,
        );

        if (!editing) {
          return IgnorePointer(child: painting);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails details) {
            _startStroke(details, size);
          },
          onPanUpdate: (DragUpdateDetails details) {
            _continueStroke(details, size);
          },
          child: painting,
        );
      },
    );
  }
}

class StoryDrawingPainter extends CustomPainter {
  const StoryDrawingPainter(this.strokes);

  final List<StoryDrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final StoryDrawingStroke stroke in strokes) {
      if (stroke.points.isEmpty) {
        continue;
      }

      final Paint paint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final Path path = Path();
      final StoryDrawingPoint first = stroke.points.first;
      path.moveTo(first.x * size.width, first.y * size.height);

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          Offset(first.x * size.width, first.y * size.height),
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      for (int index = 1; index < stroke.points.length; index++) {
        final StoryDrawingPoint point = stroke.points[index];
        path.lineTo(point.x * size.width, point.y * size.height);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StoryDrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
