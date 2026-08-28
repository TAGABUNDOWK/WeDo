import 'package:flutter/material.dart';

enum ChatBackgroundStyle {
  none,
  dotGrid,
  waves,
  clouds,
  leaves,
  bokeh,
  starfield,
  geometric,
  petals,
}

class AppChatTheme {
  final String id;
  final String name;
  final Color background;
  final Color surface;
  final Color sentBubble;
  final Color receivedBubble;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color appBarBackground;
  final Color composerBackground;
  final Color inputBackground;
  final bool isDark;
  final ChatBackgroundStyle backgroundStyle;
  final double backgroundOpacity;

  const AppChatTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.sentBubble,
    required this.receivedBubble,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.appBarBackground,
    required this.composerBackground,
    required this.inputBackground,
    this.isDark = false,
    this.backgroundStyle = ChatBackgroundStyle.none,
    this.backgroundOpacity = 0.15,
  });

  static String _colorToHex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static String _bgStyleToString(ChatBackgroundStyle style) => style.name;

  static ChatBackgroundStyle _stringToBgStyle(String? value) {
    if (value == null) return ChatBackgroundStyle.none;
    return ChatBackgroundStyle.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ChatBackgroundStyle.none,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'background': _colorToHex(background),
        'surface': _colorToHex(surface),
        'sentBubble': _colorToHex(sentBubble),
        'receivedBubble': _colorToHex(receivedBubble),
        'accent': _colorToHex(accent),
        'textPrimary': _colorToHex(textPrimary),
        'textSecondary': _colorToHex(textSecondary),
        'divider': _colorToHex(divider),
        'appBarBackground': _colorToHex(appBarBackground),
        'composerBackground': _colorToHex(composerBackground),
        'inputBackground': _colorToHex(inputBackground),
        'isDark': isDark,
        'backgroundStyle': _bgStyleToString(backgroundStyle),
        'backgroundOpacity': backgroundOpacity,
      };

  factory AppChatTheme.fromFirestore(Map<String, dynamic> data) =>
      AppChatTheme(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        background: _hexToColor(data['background'] ?? '#FFFFFF'),
        surface: _hexToColor(data['surface'] ?? '#F0F2F5'),
        sentBubble: _hexToColor(data['sentBubble'] ?? '#D9FDD3'),
        receivedBubble: _hexToColor(data['receivedBubble'] ?? '#FFFFFF'),
        accent: _hexToColor(data['accent'] ?? '#25D366'),
        textPrimary: _hexToColor(data['textPrimary'] ?? '#111B21'),
        textSecondary: _hexToColor(data['textSecondary'] ?? '#667781'),
        divider: _hexToColor(data['divider'] ?? '#E9EDEF'),
        appBarBackground: _hexToColor(data['appBarBackground'] ?? '#FFFFFF'),
        composerBackground: _hexToColor(data['composerBackground'] ?? '#F0F2F5'),
        inputBackground: _hexToColor(data['inputBackground'] ?? '#FFFFFF'),
        isDark: data['isDark'] ?? false,
        backgroundStyle: _stringToBgStyle(data['backgroundStyle']),
        backgroundOpacity: (data['backgroundOpacity'] as num?)?.toDouble() ?? 0.15,
      );

  AppChatTheme copyWith({
    String? id,
    String? name,
    Color? background,
    Color? surface,
    Color? sentBubble,
    Color? receivedBubble,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? appBarBackground,
    Color? composerBackground,
    Color? inputBackground,
    bool? isDark,
    ChatBackgroundStyle? backgroundStyle,
    double? backgroundOpacity,
  }) =>
      AppChatTheme(
        id: id ?? this.id,
        name: name ?? this.name,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        sentBubble: sentBubble ?? this.sentBubble,
        receivedBubble: receivedBubble ?? this.receivedBubble,
        accent: accent ?? this.accent,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        divider: divider ?? this.divider,
        appBarBackground: appBarBackground ?? this.appBarBackground,
        composerBackground: composerBackground ?? this.composerBackground,
        inputBackground: inputBackground ?? this.inputBackground,
        isDark: isDark ?? this.isDark,
        backgroundStyle: backgroundStyle ?? this.backgroundStyle,
        backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      );

  static const List<AppChatTheme> presets = [
    AppChatTheme(
      id: 'classic',
      name: 'Classic',
      background: Color(0xFFF0F2F5),
      surface: Color(0xFFFFFFFF),
      sentBubble: Color(0xFFD9FDD3),
      receivedBubble: Color(0xFFFFFFFF),
      accent: Color(0xFF25D366),
      textPrimary: Color(0xFF111B21),
      textSecondary: Color(0xFF667781),
      divider: Color(0xFFE9EDEF),
      appBarBackground: Color(0xFF008069),
      composerBackground: Color(0xFFF0F2F5),
      inputBackground: Color(0xFFFFFFFF),
      backgroundStyle: ChatBackgroundStyle.dotGrid,
      backgroundOpacity: 0.12,
    ),
    AppChatTheme(
      id: 'ocean',
      name: 'Ocean',
      background: Color(0xFFF0F8FF),
      surface: Color(0xFFFFFFFF),
      sentBubble: Color(0xFFD4EFFF),
      receivedBubble: Color(0xFFFFFFFF),
      accent: Color(0xFF1E90FF),
      textPrimary: Color(0xFF0D1B2A),
      textSecondary: Color(0xFF5C7A99),
      divider: Color(0xFFD6E8F5),
      appBarBackground: Color(0xFF1565C0),
      composerBackground: Color(0xFFF0F8FF),
      inputBackground: Color(0xFFFFFFFF),
      backgroundStyle: ChatBackgroundStyle.waves,
      backgroundOpacity: 0.15,
    ),
    AppChatTheme(
      id: 'sunset',
      name: 'Sunset',
      background: Color(0xFFFFF8F5),
      surface: Color(0xFFFFFFFF),
      sentBubble: Color(0xFFFFE4D6),
      receivedBubble: Color(0xFFFFFFFF),
      accent: Color(0xFFFF6B6B),
      textPrimary: Color(0xFF2D1B1B),
      textSecondary: Color(0xFF8B6F6F),
      divider: Color(0xFFF5DDD4),
      appBarBackground: Color(0xFFE65100),
      composerBackground: Color(0xFFFFF8F5),
      inputBackground: Color(0xFFFFFFFF),
      backgroundStyle: ChatBackgroundStyle.clouds,
      backgroundOpacity: 0.18,
    ),
    AppChatTheme(
      id: 'forest',
      name: 'Forest',
      background: Color(0xFFF0FFF4),
      surface: Color(0xFFFFFFFF),
      sentBubble: Color(0xFFD4EDDA),
      receivedBubble: Color(0xFFFFFFFF),
      accent: Color(0xFF28A745),
      textPrimary: Color(0xFF1A3A1A),
      textSecondary: Color(0xFF5A7A5A),
      divider: Color(0xFFD4EDDA),
      appBarBackground: Color(0xFF2E7D32),
      composerBackground: Color(0xFFF0FFF4),
      inputBackground: Color(0xFFFFFFFF),
      backgroundStyle: ChatBackgroundStyle.leaves,
      backgroundOpacity: 0.15,
    ),
    AppChatTheme(
      id: 'lavender',
      name: 'Lavender',
      background: Color(0xFFF8F0FF),
      surface: Color(0xFFFFFFFF),
      sentBubble: Color(0xFFE8D5FF),
      receivedBubble: Color(0xFFFFFFFF),
      accent: Color(0xFF9B59B6),
      textPrimary: Color(0xFF2D1B3D),
      textSecondary: Color(0xFF7A5F8A),
      divider: Color(0xFFE8D5F0),
      appBarBackground: Color(0xFF7B1FA2),
      composerBackground: Color(0xFFF8F0FF),
      inputBackground: Color(0xFFFFFFFF),
      backgroundStyle: ChatBackgroundStyle.bokeh,
      backgroundOpacity: 0.15,
    ),
    AppChatTheme(
      id: 'midnight',
      name: 'Midnight',
      background: Color(0xFF0D1117),
      surface: Color(0xFF161B22),
      sentBubble: Color(0xFF1A2332),
      receivedBubble: Color(0xFF21262D),
      accent: Color(0xFF58A6FF),
      textPrimary: Color(0xFFC9D1D9),
      textSecondary: Color(0xFF8B949E),
      divider: Color(0xFF21262D),
      appBarBackground: Color(0xFF161B22),
      composerBackground: Color(0xFF0D1117),
      inputBackground: Color(0xFF21262D),
      isDark: true,
      backgroundStyle: ChatBackgroundStyle.starfield,
      backgroundOpacity: 0.3,
    ),
    AppChatTheme(
      id: 'dark_green',
      name: 'Dark Green',
      background: Color(0xFF0A1A0A),
      surface: Color(0xFF142814),
      sentBubble: Color(0xFF1A3A1A),
      receivedBubble: Color(0xFF1E3E1E),
      accent: Color(0xFF4CAF50),
      textPrimary: Color(0xFFC8E6C9),
      textSecondary: Color(0xFF81C784),
      divider: Color(0xFF1E3E1E),
      appBarBackground: Color(0xFF142814),
      composerBackground: Color(0xFF0A1A0A),
      inputBackground: Color(0xFF1E3E1E),
      isDark: true,
      backgroundStyle: ChatBackgroundStyle.geometric,
      backgroundOpacity: 0.12,
    ),
    AppChatTheme(
      id: 'rose',
      name: 'Rose',
      background: Color(0xFFFFF0F3),
      surface: Color(0xFFFFFFFF),
      sentBubble: Color(0xFFFFD6E0),
      receivedBubble: Color(0xFFFFFFFF),
      accent: Color(0xFFE91E63),
      textPrimary: Color(0xFF3D1525),
      textSecondary: Color(0xFF8A5070),
      divider: Color(0xFFF5D6E0),
      appBarBackground: Color(0xFFC2185B),
      composerBackground: Color(0xFFFFF0F3),
      inputBackground: Color(0xFFFFFFFF),
      backgroundStyle: ChatBackgroundStyle.petals,
      backgroundOpacity: 0.15,
    ),
  ];
}
