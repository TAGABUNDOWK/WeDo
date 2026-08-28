import 'package:flutter/material.dart';
import '../models/chat_theme.dart';

class ChatThemePicker extends StatelessWidget {
  final String? currentThemeId;
  final ValueChanged<String?> onSelected;

  const ChatThemePicker({
    super.key,
    this.currentThemeId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final allOptions = [
      _ThemeOption(id: null, name: 'Default', accent: const Color(0xFF9E9E9E)),
      ...AppChatTheme.presets.map(
        (t) => _ThemeOption(id: t.id, name: t.name, accent: t.accent),
      ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: allOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final opt = allOptions[index];
          final isSelected = opt.id == currentThemeId;
          return GestureDetector(
            onTap: () => onSelected(opt.id),
            child: Tooltip(
              message: opt.name,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: opt.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: opt.accent.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : opt.id == null
                        ? Icon(Icons.refresh, color: Colors.white.withValues(alpha: 0.7), size: 16)
                        : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThemeOption {
  final String? id;
  final String name;
  final Color accent;
  const _ThemeOption({required this.id, required this.name, required this.accent});
}
