import 'package:flutter/material.dart';
import '../utils/time_format.dart';

const bg = Color(0xFF190831);

class ChatTile extends StatelessWidget {
  final String name;
  final String? lastMessage;
  final dynamic lastMessageAt;
  final int memberCount;
  final bool isGroup;
  final bool hasUnread;
  final String? lastSenderId;
  final String? currentUserId;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.memberCount,
    this.isGroup = true,
    this.hasUnread = false,
    this.lastSenderId,
    this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFromMe = lastSenderId != null && lastSenderId == currentUserId;
    final showUnread = hasUnread && !isFromMe;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isGroup ? Icons.group : Icons.person,
                      color: Color(0xFFFE4EF0),
                    ),
                  ),
                  if (showUnread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: showUnread ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage?.isNotEmpty == true ? lastMessage! : 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: showUnread ? FontWeight.w600 : FontWeight.w400,
                              color: lastMessage?.isNotEmpty == true
                                  ? (showUnread ? Colors.white : Colors.white70)
                                  : Colors.white54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatListTime(lastMessageAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: showUnread ? Colors.blue : Colors.white54,
                            fontWeight: showUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
