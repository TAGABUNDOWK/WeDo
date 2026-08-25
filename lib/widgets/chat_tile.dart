import 'package:flutter/material.dart';
import '../utils/time_format.dart';

class ChatTile extends StatelessWidget {
  final String name;
  final String? lastMessage;
  final dynamic lastMessageAt;
  final int memberCount;
  final bool isGroup;
  final bool hasUnread;
  final int unreadCount;
  final String? lastSenderId;
  final String? currentUserId;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.memberCount,
    this.isGroup = true,
    this.hasUnread = false,
    this.unreadCount = 0,
    this.lastSenderId,
    this.currentUserId,
    this.avatarUrl,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isFromMe = lastSenderId != null && lastSenderId == currentUserId;
    final showUnread = hasUnread && !isFromMe;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                      backgroundImage:
                          avatarUrl != null && avatarUrl!.isNotEmpty
                              ? NetworkImage(avatarUrl!)
                              : null,
                      child: avatarUrl == null || avatarUrl!.isEmpty
                          ? Icon(
                              isGroup ? Icons.group : Icons.person,
                              color: const Color(0xFFFE4EF0),
                              size: 26,
                            )
                          : null,
                    ),
                    if (showUnread && unreadCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFE4EF0),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (showUnread)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFE4EF0),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight:
                                    showUnread ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatListTime(lastMessageAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: showUnread
                                  ? const Color(0xFFFE4EF0)
                                  : Colors.white.withValues(alpha: 0.4),
                              fontWeight:
                                  showUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage?.isNotEmpty == true
                                  ? lastMessage!
                                  : 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: lastMessage?.isNotEmpty == true
                                    ? (showUnread
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5))
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          if (showUnread && unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFE4EF0),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ] else if (showUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFE4EF0),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
