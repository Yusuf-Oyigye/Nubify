// Makes the Android app icon and the notification icon
// from the Nubify logo on the signup screen
// (assets/images/nubify_logo.webp).
//
// Run it from the project folder after changing the logo:
//
//   flutter test tool/icons/make_icons_test.dart
//
// It writes:
// - res/drawable-*/ic_stat_nubify.png: the white logo
//   shape Android shows next to "Nubify" on every
//   notification (Android colours it Nubify blue).
// - res/mipmap-*/ic_launcher.png and
//   ic_launcher_foreground.png: the home-screen icon.
// - tool/icons/preview.png: a quick look at the cut-out.
// - play_store/: the pictures Google Play asks for:
//   nubify_play_icon_512.png (512 x 512 app icon) and
//   nubify_feature_graphic_1024x500.png (the banner on
//   top of the store page).

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const String _logo = 'assets/images/nubify_logo.webp';
const String _res = 'android/app/src/main/res';

void main() {
  testWidgets('make the Nubify icons', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final _Logo logo = await _Logo.load(_logo);

      // Drop the line and tagline under "Nubify" (keep the
      // tail of its "y", on the right).
      logo.clear(0, 1085, 845, logo.height);

      // The emblem (arc, three circles, roof) and the
      // "Nubify" word.
      final _Box emblem = logo.bounds(0, 150, logo.width, 775);
      final _Box word = logo.bounds(0, 775, logo.width, 1150);
      final _Box both = emblem.union(word);

      File('tool/icons/preview.png').writeAsBytesSync(
        logo.render(512, both, 0.9, background: const <int>[30, 30, 30]),
      );

      // Notification icon: 24dp, the emblem only (the
      // word is unreadable that small).
      const Map<String, int> notification = <String, int>{
        'mdpi': 24,
        'hdpi': 36,
        'xhdpi': 48,
        'xxhdpi': 72,
        'xxxhdpi': 96,
      };
      for (final MapEntry<String, int> size in notification.entries) {
        _write(
          '$_res/drawable-${size.key}/ic_stat_nubify.png',
          logo.render(size.value, emblem, 22 / 24),
        );
      }

      // Home-screen icon. Android 8+ cuts the 108dp
      // foreground into a circle or squircle; everything
      // must sit inside the middle 66dp.
      const Map<String, int> launcher = <String, int>{
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final MapEntry<String, int> size in launcher.entries) {
        final int dp = size.value;
        _write(
          '$_res/mipmap-${size.key}/ic_launcher_foreground.png',
          logo.render(dp * 108 ~/ 48, both, 0.56, circle: true),
        );
        _write(
          '$_res/mipmap-${size.key}/ic_launcher.png',
          logo.render(
            dp,
            both,
            0.78,
            background: logo.blue,
            rounded: 0.18,
          ),
        );
      }

      // Google Play app icon: 512 x 512, a full square
      // (Play rounds the corners itself), no see-through.
      _write(
        'play_store/nubify_play_icon_512.png',
        logo.render(512, both, 0.7, background: logo.blue),
      );

      // Google Play feature graphic: 1024 x 500, no
      // see-through (24-bit PNG). The full logo, tagline
      // included, on a Nubify blue gradient, kept away
      // from the edges.
      final _Logo full = await _Logo.load(_logo);
      final _Box everything = full.bounds(0, 150, full.width, full.height);
      _write(
        'play_store/nubify_feature_graphic_1024x500.png',
        full.render(
          1024,
          everything,
          0.74,
          height: 500,
          background: full.blue,
          background2: const <int>[0x15, 0x46, 0xC9],
          alpha: false,
        ),
      );

      final String hex = logo.blue
          .map((int c) => c.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
      // ignore: avoid_print
      print('Logo blue: #$hex (res/values/colors.xml ic_launcher_background)');
    });
  });
}

void _write(String path, Uint8List png) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png);
}

//===================================================
// THE LOGO AS A WHITE SHAPE
//===================================================

class _Box {
  const _Box(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;

  _Box union(_Box other) => _Box(
    math.min(left, other.left),
    math.min(top, other.top),
    math.max(right, other.right),
    math.max(bottom, other.bottom),
  );
}

class _Logo {
  _Logo(this.width, this.height, this.white, this.blue);

  final int width;
  final int height;

  // How white each pixel is, 0..1 (the logo is white
  // on blue).
  final Float32List white;

  // The logo's blue, for the app icon background.
  final List<int> blue;

  static Future<_Logo> load(String path) async {
    final ui.Codec codec = await ui.instantiateImageCodec(
      File(path).readAsBytesSync(),
    );
    final ui.Image image = (await codec.getNextFrame()).image;
    final ByteData rgba = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;

    final int width = image.width;
    final int height = image.height;
    final Float32List white = Float32List(width * height);
    final List<int> sum = <int>[0, 0, 0];
    int count = 0;

    for (int i = 0; i < width * height; i++) {
      final int r = rgba.getUint8(i * 4);
      final int g = rgba.getUint8(i * 4 + 1);
      final int b = rgba.getUint8(i * 4 + 2);

      // White and its soft edge count; the blue and the
      // light-blue glow around the shapes do not.
      final int lowest = math.min(r, math.min(g, b));
      white[i] = ((lowest - 150) / 60).clamp(0.0, 1.0);

      if (lowest < 60) {
        sum[0] += r;
        sum[1] += g;
        sum[2] += b;
        count++;
      }
    }

    return _Logo(
      width,
      height,
      white,
      sum.map((int total) => total ~/ math.max(count, 1)).toList(),
    );
  }

  /// Leaves the area out of every icon.
  void clear(int left, int top, int right, int bottom) {
    for (int y = top; y < bottom; y++) {
      white.fillRange(y * width + left, y * width + right, 0);
    }
  }

  /// The smallest box around the white inside the area.
  _Box bounds(int left, int top, int right, int bottom) {
    int minX = right, minY = bottom, maxX = left, maxY = top;
    for (int y = top; y < bottom; y++) {
      for (int x = left; x < right; x++) {
        if (white[y * width + x] > 0.5) {
          minX = math.min(minX, x);
          maxX = math.max(maxX, x + 1);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y + 1);
        }
      }
    }
    return _Box(minX, minY, maxX, maxY);
  }

  /// A [size] x [size] PNG (or [size] x [height]) with the
  /// white of [box] in the middle, [fill] of the width (or,
  /// with [circle], of the circle around it). Transparent
  /// unless [background] is given ([background2] makes it
  /// a gradient to the bottom right); [rounded] rounds its
  /// corners; [alpha] false writes a 24-bit PNG.
  Uint8List render(
    int size,
    _Box box,
    double fill, {
    int? height,
    bool circle = false,
    List<int>? background,
    List<int>? background2,
    double rounded = 0,
    bool alpha = true,
  }) {
    final int outWidth = size;
    final int tall = height ?? size;

    double scale;
    if (circle) {
      final double diagonal = math.sqrt(
        box.width * box.width + box.height * box.height,
      );
      scale = size * fill / diagonal;
    } else {
      scale = math.min(
        outWidth * fill / box.width,
        tall * fill / box.height,
      );
    }

    final double drawnWidth = box.width * scale;
    final double drawnHeight = box.height * scale;
    final double offsetX = (outWidth - drawnWidth) / 2;
    final double offsetY = (tall - drawnHeight) / 2;

    final Uint8List pixels = Uint8List(outWidth * tall * 4);

    for (int ty = 0; ty < tall; ty++) {
      for (int tx = 0; tx < outWidth; tx++) {
        // Average every logo pixel under this icon pixel.
        final double sx0 = box.left + (tx - offsetX) / scale;
        final double sy0 = box.top + (ty - offsetY) / scale;
        final double sx1 = sx0 + 1 / scale;
        final double sy1 = sy0 + 1 / scale;

        double cover = 0;
        if (sx1 > box.left &&
            sx0 < box.right &&
            sy1 > box.top &&
            sy0 < box.bottom) {
          final int x0 = math.max(box.left, sx0.floor());
          final int x1 = math.min(box.right, sx1.ceil());
          final int y0 = math.max(box.top, sy0.floor());
          final int y1 = math.min(box.bottom, sy1.ceil());
          double total = 0;
          int n = 0;
          for (int y = y0; y < y1; y++) {
            for (int x = x0; x < x1; x++) {
              total += white[y * width + x];
              n++;
            }
          }
          cover = n == 0 ? 0 : total / n;
        }

        final int i = (ty * outWidth + tx) * 4;
        if (background == null) {
          pixels[i] = 255;
          pixels[i + 1] = 255;
          pixels[i + 2] = 255;
          pixels[i + 3] = (cover * 255).round();
        } else {
          // How far along the gradient (top left 0, bottom
          // right 1).
          final double along = (tx / outWidth + ty / tall) / 2;
          for (int c = 0; c < 3; c++) {
            final double base = background2 == null
                ? background[c].toDouble()
                : background[c] + (background2[c] - background[c]) * along;
            pixels[i + c] = (base + (255 - base) * cover).round();
          }
          pixels[i + 3] = (_inside(tx, ty, size, rounded) * 255).round();
        }
      }
    }

    return _png(outWidth, tall, pixels, alpha: alpha);
  }

  // How much of the pixel is inside the rounded square
  // (4 x 4 samples for smooth corners).
  static double _inside(int x, int y, int size, double rounded) {
    if (rounded <= 0) return 1;
    final double radius = size * rounded;
    int hits = 0;
    for (int sy = 0; sy < 4; sy++) {
      for (int sx = 0; sx < 4; sx++) {
        final double px = x + (sx + 0.5) / 4;
        final double py = y + (sy + 0.5) / 4;
        final double cx = px.clamp(radius, size - radius);
        final double cy = py.clamp(radius, size - radius);
        final double dx = px - cx;
        final double dy = py - cy;
        if (dx * dx + dy * dy <= radius * radius) hits++;
      }
    }
    return hits / 16;
  }
}

//===================================================
// SMALL PNG WRITER (RGBA, no extra packages)
//===================================================

Uint8List _png(int width, int height, Uint8List rgba, {bool alpha = true}) {
  final BytesBuilder raw = BytesBuilder();
  for (int y = 0; y < height; y++) {
    raw.addByte(0);
    final Uint8List row = rgba.sublist(y * width * 4, (y + 1) * width * 4);
    if (alpha) {
      raw.add(row);
    } else {
      // RGB only.
      for (int x = 0; x < width; x++) {
        raw.add(row.sublist(x * 4, x * 4 + 3));
      }
    }
  }

  final BytesBuilder out = BytesBuilder()
    ..add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final ByteData header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, alpha ? 6 : 2);
  _chunk(out, 'IHDR', header.buffer.asUint8List());
  _chunk(out, 'IDAT', Uint8List.fromList(ZLibCodec(level: 9).encode(raw.toBytes())));
  _chunk(out, 'IEND', Uint8List(0));
  return out.toBytes();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final Uint8List typed = Uint8List.fromList(type.codeUnits);
  final ByteData length = ByteData(4)..setUint32(0, data.length);
  final ByteData crc = ByteData(4)
    ..setUint32(0, _crc(<int>[...typed, ...data]));
  out
    ..add(length.buffer.asUint8List())
    ..add(typed)
    ..add(data)
    ..add(crc.buffer.asUint8List());
}

final List<int> _crcTable = List<int>.generate(256, (int n) {
  int c = n;
  for (int k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  int c = 0xFFFFFFFF;
  for (final int byte in bytes) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
