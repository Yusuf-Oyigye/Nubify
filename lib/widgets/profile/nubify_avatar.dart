import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../utils/faculties/faculty_catalog.dart';

//===================================================
// NUBIFY AVATARS
//
// A male and a female avatar, coloured by faculty. New
// students who skip the profile photo get one of these
// (saved as their picture), so every faculty has its
// own look across the app.
//===================================================

abstract final class NubifyGender {
  static const String male = 'male';
  static const String female = 'female';

  static bool isValid(String? value) => value == male || value == female;
}

//===================================================
// AVATAR COLOUR FOR EACH FACULTY
//
// Change a colour here to choose a faculty's avatar
// colour. Faculties not listed use their badge colour.
//===================================================

abstract final class NubifyAvatarColors {
  static const Map<String, Color> byFacultyId = <String, Color>{
    'medicine': Color(0xFF29B6F6),
    'oral_dental_medicine': Color(0xFF2EAD70),
    'pharmacy': Color(0xFFC6539B),
    'engineering': Color(0xFF607D8B),
    'computer_science': Color(0xFFC62828),
    'business_administration': Color(0xFFD59B18),
    'mass_communication_languages': Color(0xFF14286B),
    'physical_therapy': Color(0xFF12A7B8),
    'fine_arts': Color(0xFF8E5AD7),
    'nursing': Color(0xFFE76F8A),
    'other': Color(0xFF37474F),
  };

  /// Before a faculty is chosen.
  static const Color neutral = Color(0xFF2F6BFF);

  /// [faculty] may be a faculty id or a faculty name.
  static Color forFaculty(String? faculty) {
    final String value = (faculty ?? '').trim();
    if (value.isEmpty) return neutral;

    final NubifyFaculty match =
        NubifyFacultyCatalog.byId(value) ??
        NubifyFacultyCatalog.displayFor(value);

    return byFacultyId[match.id] ?? match.color;
  }
}

//===================================================
// PAINTER
//===================================================

class NubifyAvatarPainter extends CustomPainter {
  const NubifyAvatarPainter({required this.female, required this.color});

  final bool female;
  final Color color;

  Color _shade(double amount) =>
      Color.lerp(color, Colors.black, amount) ?? color;

  Color _tint(double amount) =>
      Color.lerp(color, Colors.white, amount) ?? color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Rect box = Offset.zero & Size(s, s);
    final Offset c = box.center;

    canvas.save();
    canvas.clipPath(Path()..addOval(box));

    // Background: the faculty colour, lighter at the top.
    canvas.drawRect(
      box,
      Paint()
        ..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, <Color>[
          _tint(0.25),
          _shade(0.18),
        ]),
    );

    // Soft light behind the head.
    canvas.drawCircle(
      Offset(c.dx, s * 0.42),
      s * 0.42,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    final Paint hair = Paint()..color = _shade(0.55);
    final Paint skin = Paint()..color = const Color(0xFFF7F3EE);
    final Paint top = Paint()
      ..shader = ui.Gradient.linear(
        Offset(c.dx, s * 0.7),
        Offset(c.dx, s),
        <Color>[Colors.white, const Color(0xFFE6EAF2)],
      );

    final double headR = s * 0.19;
    final Offset head = Offset(c.dx, s * 0.43);

    // Long hair falls behind the head and shoulders.
    if (female) {
      final Path back = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(c.dx, s * 0.55),
              width: headR * 2.55,
              height: s * 0.46,
            ),
            Radius.circular(headR * 1.1),
          ),
        );
      canvas.drawPath(back, hair);
    }

    // Shoulders (a rounded top).
    final Path body = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(s * 0.18, s * 0.73, s * 0.64, s * 0.4),
          topLeft: Radius.circular(s * 0.26),
          topRight: Radius.circular(s * 0.26),
        ),
      );
    canvas.drawPath(body, top);

    // Collar in the faculty colour.
    final Path collar = Path()
      ..moveTo(c.dx - s * 0.09, s * 0.74)
      ..lineTo(c.dx, s * 0.83)
      ..lineTo(c.dx + s * 0.09, s * 0.74)
      ..close();
    canvas.drawPath(collar, Paint()..color = _shade(0.1));

    // Neck.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, s * 0.66),
          width: headR * 0.9,
          height: s * 0.14,
        ),
        Radius.circular(s * 0.04),
      ),
      skin,
    );

    // Head.
    canvas.drawCircle(head, headR, skin);

    // Hair on top.
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: head, radius: headR * 1.08)),
    );
    if (female) {
      final Path fringe = Path()
        ..addOval(
          Rect.fromCenter(
            center: Offset(head.dx + headR * 0.15, head.dy - headR * 0.72),
            width: headR * 2.6,
            height: headR * 1.5,
          ),
        );
      canvas.drawPath(fringe, hair);
    } else {
      final Path cap = Path()
        ..addOval(
          Rect.fromCenter(
            center: Offset(head.dx, head.dy - headR * 0.78),
            width: headR * 2.4,
            height: headR * 1.25,
          ),
        );
      canvas.drawPath(cap, hair);
    }
    canvas.restore();

    if (female) {
      // Side locks framing the face.
      for (final double side in <double>[-1, 1]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(
                head.dx + side * headR * 1.1,
                head.dy + headR * 0.28,
              ),
              width: headR * 0.38,
              height: headR * 1.75,
            ),
            Radius.circular(headR * 0.25),
          ),
          hair,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(NubifyAvatarPainter oldDelegate) =>
      oldDelegate.female != female || oldDelegate.color != color;

  //===================================================
  // SAVE AS A PICTURE
  //===================================================

  /// The avatar as a PNG, e.g. to save as a profile photo.
  static Future<Uint8List> renderPng({
    required bool female,
    required Color color,
    int size = 512,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    NubifyAvatarPainter(
      female: female,
      color: color,
    ).paint(canvas, Size(size.toDouble(), size.toDouble()));

    final ui.Image image = await recorder.endRecording().toImage(size, size);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();

    if (bytes == null) {
      throw StateError('Could not draw the avatar.');
    }
    return bytes.buffer.asUint8List();
  }
}

//===================================================
// WIDGET
//===================================================

class NubifyAvatar extends StatelessWidget {
  const NubifyAvatar({
    super.key,
    required this.gender,
    required this.faculty,
    this.size = 120,
  });

  /// [NubifyGender.male] or [NubifyGender.female].
  final String gender;

  /// Faculty id or name; empty uses the neutral blue.
  final String? faculty;

  final double size;

  @override
  Widget build(BuildContext context) {
    final bool female = gender == NubifyGender.female;

    return Semantics(
      image: true,
      label: female ? 'Female avatar' : 'Male avatar',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: NubifyAvatarPainter(
            female: female,
            color: NubifyAvatarColors.forFaculty(faculty),
          ),
        ),
      ),
    );
  }
}
