import 'package:flutter/material.dart';

class WheelPalette {
  static const _seedColor = Color(0xFF7C3AED);

  static List<Color> generate(int count) {
    final hsl = HSLColor.fromColor(_seedColor);
    final baseHue = hsl.hue;
    final colors = <Color>[];
    for (int i = 0; i < count; i++) {
      final hue = (baseHue + (i * 270.0 / count)) % 360;
      colors.add(
        HSLColor.fromAHSL(
          1.0,
          hue,
          0.75,
          0.50,
        ).toColor(),
      );
    }
    return colors;
  }

  static Color colorForIndex(int index, {int total = 8}) {
    final palette = generate(total);
    return palette[index % palette.length];
  }
}
