import 'package:flutter/material.dart';

class EmptyChats extends StatelessWidget {
  final VoidCallback onCreate;

  const EmptyChats({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined, size: 40, color: Color(0xFFFE4EF0)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No chats yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a group chat with your friends',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.group_add),
            label: const Text('Create group chat'),
          ),
        ],
      ),
    );
  }
}
