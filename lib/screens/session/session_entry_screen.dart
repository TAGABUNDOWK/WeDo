import 'package:flutter/material.dart';
import 'create_session_screen.dart';
import 'join_session_screen.dart';

class SessionEntryScreen extends StatelessWidget {
  const SessionEntryScreen({super.key});

  static const _bg = Color(0xFFE7ECEF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Sessions',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCreateButton(context),
            const SizedBox(height: 12),
            _buildJoinButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateSessionScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF2A6FD6),
              offset: Offset(0, 6),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Host a game with friends',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JoinSessionScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 12),
            BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(6, 6), blurRadius: 12),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.login, color: Colors.blue, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join Session',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Enter a session code to join',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
