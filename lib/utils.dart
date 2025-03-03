import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

Future<Uint8List?> captureChart(GlobalKey chartKey) async {
  try {
    RenderRepaintBoundary boundary =
        chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 1.2);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (e) {
    print("Error capturing chart: $e");
    return null;
  }
}


String shortenNumber(double? num) {
  if (num == null) return '0';
  if (num >= 1e9) return '${(num / 1e9).toStringAsFixed(1)} B'; // Миллиарды
  if (num >= 1e6) return '${(num / 1e6).toStringAsFixed(1)} M'; // Миллионы
  if (num >= 1e3) return '${(num / 1e3).toStringAsFixed(1)} K'; // Тысячи
  return num.toStringAsFixed(0);
}


