import 'package:flutter/widgets.dart';

class Responsive {
  const Responsive._();

  static const double _designWidth = 393;

  static double scale(BuildContext context) =>
      MediaQuery.of(context).size.width / _designWidth;

  static double cardWidth(BuildContext context) =>
      (MediaQuery.of(context).size.width * 0.78).clamp(360.0, 760.0);

  static double cardHeight(BuildContext context) =>
      (cardWidth(context) * 0.56).clamp(202.0, 426.0);

  static double appBarIconSize(BuildContext context) =>
      (28 * scale(context)).clamp(20.0, 36.0);

  static double logoWidth(BuildContext context) =>
      (50 * scale(context)).clamp(36.0, 72.0);

  static double coverflowPadding(BuildContext context) =>
      MediaQuery.of(context).size.height / 2 - cardHeight(context) / 2;

  static double centerThreshold(BuildContext context) =>
      (12 * scale(context)).clamp(8.0, 18.0);

  static double topicIconSize(BuildContext context) =>
      (28 * scale(context)).clamp(18.0, 36.0);

  static double topicLabelSize(BuildContext context) =>
      (13 * scale(context)).clamp(10.0, 16.0);
}
