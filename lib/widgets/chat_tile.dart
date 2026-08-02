import 'package:flutter/material.dart';
import '../utils/time_format.dart';

const bg = Color(0xFFE7ECEF);

class ChatTile extends StatelessWidget {
  final String name;
  final String? lastMessage;
  final dynamic lastMessageAt;
  final int memberCount;
  final bool isGroup;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.memberCount,
    this.isGroup = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 12),
              BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(6, 6), blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGroup ? Icons.group : Icons.person,
                  color: Colors.blue,
                ),
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
                              color: lastMessage?.isNotEmpty == true
                                  ? Colors.black54
                                  : Colors.black26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatListTime(lastMessageAt),
                          style: const TextStyle(fontSize: 11, color: Colors.black38),
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
