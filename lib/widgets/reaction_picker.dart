import 'package:flutter/material.dart';
import '../models/chat_theme.dart';

class ReactionPicker extends StatelessWidget {
  final String? currentReaction;
  final ValueChanged<String> onReact;
  final AppChatTheme? theme;

  const ReactionPicker({
    super.key,
    this.currentReaction,
    required this.onReact,
    this.theme,
  });

  static const List<String> _emojis = ['❤️', '😂', '😮', '😢', '😡', '👍', '👎', '🔥'];

  static void show(
    BuildContext context, {
    required String? currentReaction,
    required ValueChanged<String> onReact,
    AppChatTheme? theme,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme?.composerBackground ?? Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ReactionPicker(
        currentReaction: currentReaction,
        onReact: (emoji) {
          Navigator.pop(context);
          onReact(emoji);
        },
        theme: theme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = theme?.composerBackground ?? Theme.of(context).scaffoldBackgroundColor;
    final accentColor = theme?.accent ?? Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _emojis.map((emoji) {
            final isSelected = currentReaction == emoji;
            return GestureDetector(
              onTap: () => onReact(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: accentColor.withValues(alpha: 0.4), width: 1)
                      : null,
                ),
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: isSelected ? 30 : 26,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
