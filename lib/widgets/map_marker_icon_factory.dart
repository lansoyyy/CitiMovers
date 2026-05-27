import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerIconFactory {
  MapMarkerIconFactory._();

  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> fromIcon(
    IconData icon,
    Color color, {
    double size = 72,
  }) async {
    final cacheKey = '${icon.codePoint}_${color.toARGB32()}_$size';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final descriptor = await _createIcon(icon, color, size);
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  static Future<BitmapDescriptor> vehicleIcon(
    Color color, {
    double size = 72,
    bool selected = false,
  }) {
    return fromIcon(
      Icons.local_shipping_rounded,
      color,
      size: selected ? size * 1.2 : size,
    );
  }

  static Future<BitmapDescriptor> _createIcon(
    IconData icon,
    Color color,
    double size,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = TextPainter(textDirection: TextDirection.ltr);

    painter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
        shadows: const [
          Shadow(color: Colors.white, offset: Offset(-1, -1), blurRadius: 0),
          Shadow(color: Colors.white, offset: Offset(1, -1), blurRadius: 0),
          Shadow(color: Colors.white, offset: Offset(-1, 1), blurRadius: 0),
          Shadow(color: Colors.white, offset: Offset(1, 1), blurRadius: 0),
          Shadow(
            color: Color(0x4D000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );

    painter.layout();

    final width = (painter.width + 16).ceil();
    final height = (painter.height + 16).ceil();
    painter.paint(canvas, const Offset(8, 8));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(pngBytes!.buffer.asUint8List());
  }
}
