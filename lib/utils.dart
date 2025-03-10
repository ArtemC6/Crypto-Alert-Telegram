import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

Future<Uint8List?> captureChart(GlobalKey chartKey) async {
  try {
    RenderRepaintBoundary boundary =
        chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 2.5);
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

String formatAge(int minutes) {
  if (minutes < 60) {
    return "$minutes мин";
  } else {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return "$hours ч";
    } else {
      return "$hours ч $remainingMinutes мин";
    }
  }
}

String calculateTokenAge(int createdAt) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final ageInSeconds = now - createdAt;

  if (ageInSeconds < 60) {
    return "$ageInSeconds секунд";
  } else if (ageInSeconds < 3600) {
    final minutes = (ageInSeconds / 60).floor();
    return "$minutes минут";
  } else if (ageInSeconds < 86400) {
    final hours = (ageInSeconds / 3600).floor();
    return "$hours часов";
  } else {
    final days = (ageInSeconds / 86400).floor();
    return "$days дней";
  }
}

int calculateAge(String creationTime) {
  final dateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
  final createdAt = dateFormat.parse(creationTime, true).toLocal();
  final now = DateTime.now().toLocal();
  final difference = now.difference(createdAt);

  return difference.inMinutes;
}

String formatMarketCap(dynamic marketCap) {
  if (marketCap == null) return "\$0";

  double value =
      marketCap is String ? double.parse(marketCap) : marketCap.toDouble();
  final formatter = NumberFormat("#,###", "en_US");

  if (value >= 1000000000) {
    return "\$${(value / 1000000000).toStringAsFixed(2)}B";
  } else if (value >= 1000000) {
    return "\$${(value / 1000000).toStringAsFixed(2)}M";
  } else if (value >= 1000) {
    return "\$${(value / 1000).toStringAsFixed(2)}K";
  } else {
    return "\$${formatter.format(value)}";
  }
}


// Вспомогательная функция для парсинга double
double parseDouble(dynamic value) {
  if (value is String) {
    return double.tryParse(value) ?? 0;
  } else if (value is num) {
    return value.toDouble();
  }
  return 0;
}

// Вспомогательная функция для парсинга int
int parseInt(dynamic value) {
  if (value is String) {
    return int.tryParse(value) ?? 0;
  } else if (value is num) {
    return value.toInt();
  }
  return 0;
}
