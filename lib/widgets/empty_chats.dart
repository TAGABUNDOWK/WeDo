import 'package:flutter/material.dart';

const _bg = Color(0xFFE7ECEF);

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
              color: _bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.white, offset: Offset(-5, -5), blurRadius: 10),
                BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(5, 5), blurRadius: 10),
              ],
            ),
            child: const Icon(Icons.forum_outlined, size: 40, color: Colors.blue),
          ),
          const SizedBox(height: 20),
          const Text(
            'No chats yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a group chat with your friends',
            style: TextStyle(color: Colors.black54),
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
