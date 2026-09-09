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

  // ── ChatTab phone breakpoints (width dp) ──
  // S: <360, M: 360-400, L: 400-480, XL phone: >=480.
  // Tablet (>600) / XL (>1024) guards preserved for centering only.
  static bool isSmallPhone(double w) => w < 360;
  static bool isMediumPhone(double w) => w >= 360 && w < 400;
  static bool isLargePhone(double w) => w >= 400 && w < 480;
  static bool isXLPhone(double w) => w >= 480;
  static bool isShortHeight(double h) => h < 600;
  static bool isTabletWidth(double w) => w >= 600;
  static bool isXlWidth(double w) => w > 1024;

  static double hPad(double w) => (w * 0.05).clamp(16.0, 32.0);

  static double contentMax(double w) => w > 1024 ? 720.0 : w;

  static double chatLogoSize(double w) => (w * 0.155).clamp(62.0, 84.0);

  static double chatAvatarSize(double w) => (w * 0.105).clamp(40.0, 52.0);

  static double chatTitleSize(double w) => (w * 0.075).clamp(24.0, 35.0);

  static double chatAvatarRadius(double w) => (w * 0.062).clamp(22.0, 28.0);

  static double chatNameSize(double w) => (w * 0.038).clamp(14.0, 16.0);

  static double chatPreviewSize(double w) => (w * 0.034).clamp(12.0, 14.0);

  static double chatTimeSize(double w) => (w * 0.03).clamp(10.0, 12.0);

  static double chatRowHPad(double w) => (w * 0.035).clamp(12.0, 16.0);

  static double chatRowVPad(double w) => (w * 0.03).clamp(10.0, 14.0);

  static double chatRowGap(double w) => (w * 0.03).clamp(10.0, 14.0);

  static double chatSeparator(double w) {
    if (w < 360) return 8.0;
    if (w >= 480) return 12.0;
    return 10.0;
  }

  static double chatTopVPad(double w, double h) {
    if (h < 600) return 6.0;
    if (w < 360) return 8.0;
    return 12.0;
  }

  static double fabSize(double w, double h) {
    if (h < 600) return 48.0;
    if (w < 360) return 52.0;
    if (w >= 480) return 60.0;
    return 56.0;
  }

  /// Clearance above the floating glass nav bar in HomePage.
  static double fabBottom(BuildContext context) =>
      MediaQuery.of(context).padding.bottom + 100.0;

  static double listBottom(BuildContext context) =>
      MediaQuery.of(context).padding.bottom + 120.0;

  static double sheetMaxWidth(double w) => w > 512 ? 480.0 : w - 32.0;

  static double emptyIconSize(double w) {
    if (w < 360) return 64.0;
    if (w >= 480) return 96.0;
    return 88.0;
  }

  /// Caps large accessibility text so pixel titles / pills never overflow.
  static TextScaler cappedTextScaler(BuildContext context,
      [double max = 1.3]) {
    return MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 1.0, maxScaleFactor: max);
  }
}
