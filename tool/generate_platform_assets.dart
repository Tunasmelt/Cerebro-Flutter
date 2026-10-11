// Run: flutter test tool/generate_platform_assets.dart
// Geometry/colors mirror Cerebro-2.0/apps/web/src/app/icon.svg.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void mark(Canvas canvas, double size, {bool background = true}) {
  if (background) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xff0a0a0f),
    );
  }
  canvas.save();
  canvas.translate(size * 0.17, size * 0.17);
  canvas.scale(size * 0.66 / 24);
  final teal = Paint()..color = const Color(0xff2dd4bf);
  final line = Paint()
    ..color = teal.color
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(12, 12), const Offset(5, 6), line);
  canvas.drawLine(const Offset(12, 12), const Offset(19, 6), line);
  canvas.drawLine(
    const Offset(12, 12),
    const Offset(6, 19),
    line..color = teal.color.withValues(alpha: 0.6),
  );
  canvas.drawCircle(
    const Offset(5, 6),
    2.2,
    teal..color = const Color(0xff2dd4bf).withValues(alpha: 0.85),
  );
  canvas.drawCircle(const Offset(19, 6), 2.2, teal);
  canvas.drawCircle(
    const Offset(6, 19),
    1.8,
    teal..color = const Color(0xff2dd4bf).withValues(alpha: 0.55),
  );
  canvas.drawCircle(
    const Offset(12, 12),
    3.4,
    Paint()..color = const Color(0xff8b5cf6),
  );
  canvas.restore();
}

Future<void> png(
  String path,
  int width,
  int height,
  void Function(Canvas) draw, {
  bool opaque = true,
}) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(
    format: opaque ? ui.ImageByteFormat.rawRgba : ui.ImageByteFormat.png,
  );
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    opaque
        ? _rgbPng(bytes!.buffer.asUint8List(), width, height)
        : bytes!.buffer.asUint8List(),
  );
  image.dispose();
  picture.dispose();
}

// Store icons must have no alpha channel; ui.Image's PNG output is RGBA.
// Encode its opaque RGB pixels with the standard library's zlib compressor.
Uint8List _rgbPng(Uint8List rgba, int width, int height) {
  final pixels = Uint8List((width * 3 + 1) * height);
  var offset = 0;
  for (var y = 0; y < height; y++) {
    pixels[offset++] = 0; // PNG filter: none.
    for (var x = 0; x < width; x++) {
      final source = (y * width + x) * 4;
      pixels.setRange(offset, offset + 3, rgba, source);
      offset += 3;
    }
  }
  final output = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    var crc = 0xffffffff;
    for (final byte in body) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ ((crc & 1) != 0 ? 0xedb88320 : 0);
      }
    }
    output.add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List());
    output.add(body);
    output.add(
      (ByteData(4)..setUint32(0, crc ^ 0xffffffff)).buffer.asUint8List(),
    );
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibEncoder().convert(pixels));
  chunk('IEND', []);
  return output.takeBytes();
}

void main() {
  test('generate native Cerebro branding and store artwork', () async {
    for (final entry in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await png(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        entry.value,
        entry.value,
        (canvas) => mark(canvas, entry.value.toDouble()),
      );
    }
    const iconRoot = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final manifest =
        jsonDecode(await File('$iconRoot/Contents.json').readAsString()) as Map;
    for (final entry in manifest['images'] as List) {
      final pixels =
          (double.parse((entry['size'] as String).split('x').first) *
                  double.parse((entry['scale'] as String).replaceAll('x', '')))
              .round();
      await png(
        '$iconRoot/${entry['filename']}',
        pixels,
        pixels,
        (canvas) => mark(canvas, pixels.toDouble()),
      );
    }
    for (var scale = 1; scale <= 3; scale++) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      await png(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
        96 * scale,
        96 * scale,
        (canvas) => mark(canvas, 96.0 * scale, background: false),
        opaque: false,
      );
    }
    await png(
      'release/store-assets/icon-512.png',
      512,
      512,
      (canvas) => mark(canvas, 512),
    );
    await png(
      'release/store-assets/icon-1024.png',
      1024,
      1024,
      (canvas) => mark(canvas, 1024),
    );
    final font = FontLoader('Outfit')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('assets/fonts/Outfit-VariableFont.ttf').readAsBytes(),
          ),
        ),
      );
    await font.load();
    await png('release/store-assets/feature-graphic.png', 1024, 500, (canvas) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 500),
        Paint()..color = const Color(0xff0a0a0f),
      );
      canvas.save();
      canvas.translate(60, 100);
      mark(canvas, 300, background: false);
      canvas.restore();
      final title = TextPainter(
        text: const TextSpan(
          text: 'Cerebro',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 84,
            fontWeight: FontWeight.w600,
            color: Color(0xffe2e8f0),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      title.paint(canvas, const Offset(410, 145));
      final subtitle = TextPainter(
        text: const TextSpan(
          text: 'Your knowledge, connected.',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 30,
            color: Color(0xff94a3b8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      subtitle.paint(canvas, const Offset(414, 255));
      title.dispose();
      subtitle.dispose();
    });
  });
}
