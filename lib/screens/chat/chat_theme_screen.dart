import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/chat_theme.dart';
import '../../services/theme/theme_service.dart';

class ChatThemeScreen extends StatefulWidget {
  const ChatThemeScreen({super.key});

  @override
  State<ChatThemeScreen> createState() => _ChatThemeScreenState();
}

class _ChatThemeScreenState extends State<ChatThemeScreen> {
  final _themeService = ThemeService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  String _currentThemeId = 'classic';

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
  }

  Future<void> _loadCurrentTheme() async {
    if (_currentUser == null) return;
    final theme = await _themeService.getUserTheme(_currentUser.uid);
    if (theme != null && mounted) {
      setState(() => _currentThemeId = theme.id);
    }
  }

  Future<void> _selectTheme(AppChatTheme theme) async {
    if (_currentUser == null) return;
    setState(() => _currentThemeId = theme.id);
    await _themeService.saveUserTheme(_currentUser.uid, theme);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${theme.name} theme applied'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Theme')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: AppChatTheme.presets.length,
        itemBuilder: (context, index) {
          final theme = AppChatTheme.presets[index];
          final isSelected = _currentThemeId == theme.id;

          return GestureDetector(
            onTap: () => _selectTheme(theme),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? theme.accent
                      : Colors.grey.withValues(alpha: 0.2),
                  width: isSelected ? 3 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Theme preview
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: theme.background,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    child: Column(
                      children: [
                        // App bar preview
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.appBarBackground,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Preview',
                                style: TextStyle(
                                  color: theme.isDark
                                      ? Colors.white
                                      : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Message bubbles preview
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.receivedBubble,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Hello!',
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.sentBubble,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Hey there!',
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Composer preview
                        Container(
                          height: 36,
                          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          decoration: BoxDecoration(
                            color: theme.inputBackground,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Type a message...',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Theme name + accent color
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            theme.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: theme.accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
