import '../../models/chat_theme.dart';
import 'theme_service.dart';

class ChatThemeResolver {
  final ThemeService _themeService = ThemeService();

  static final AppChatTheme defaultTheme = AppChatTheme.presets[0]; // Classic

  Future<AppChatTheme> resolve(String chatId, String collection) async {
    final themeId = await _themeService.getChatThemeId(chatId, collection);
    if (themeId == null) return defaultTheme;
    return AppChatTheme.presets.firstWhere(
      (t) => t.id == themeId,
      orElse: () => defaultTheme,
    );
  }

  Stream<AppChatTheme> resolveStream(String chatId, String collection) {
    return _themeService.getChatThemeStream(chatId, collection).map((themeId) {
      if (themeId == null) return defaultTheme;
      return AppChatTheme.presets.firstWhere(
        (t) => t.id == themeId,
        orElse: () => defaultTheme,
      );
    });
  }
}
