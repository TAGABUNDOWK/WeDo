import 'package:flutter/material.dart';

class WheelOption {
  final String label;
  final Color color;

  const WheelOption({required this.label, required this.color});

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    };
  }

  factory WheelOption.fromMap(Map<String, dynamic> map) {
    final label = map['label'] as String;
    final colorHex = map['color'] as String;
    final colorValue = int.parse(colorHex.replaceFirst('#', '0xFF'));
    return WheelOption(
      label: label,
      color: Color(colorValue),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WheelOption &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          color == other.color;

  @override
  int get hashCode => label.hashCode ^ color.hashCode;
}
