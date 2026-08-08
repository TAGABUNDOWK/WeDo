import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/session/session_service.dart';
import 'waiting_lobby_screen.dart';

class JoinSessionScreen extends StatefulWidget {
  const JoinSessionScreen({super.key});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen> {
  final _service = SessionService();
  final _bg = const Color(0xFFE7ECEF);
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  bool _isJoining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _joinSession() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Code must be 6 characters');
      return;
    }
    if (_currentUser == null || _isJoining) return;

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final session = await _service.validateSessionCode(code);

      await _service.joinSession(
        sessionId: session.sessionId,
        userId: _currentUser.uid,
        userName: _currentUser.displayName ?? _currentUser.email ?? 'Player',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingLobbyScreen(sessionId: code, isHost: false),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Join Session',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.meeting_room, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Enter the 6-character session code',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            _buildCodeInput(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 32),
            _buildJoinButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10),
          BoxShadow(color: Color(0xFFB8C6CC), offset: Offset(4, 4), blurRadius: 10),
        ],
      ),
      child: TextField(
        controller: _codeController,
        focusNode: _codeFocusNode,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        maxLength: 6,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 8,
        ),
        decoration: const InputDecoration(
          counterText: '',
          hintText: 'XXXXXX',
          hintStyle: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: Colors.black26,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        ],
        onChanged: (value) {
          if (value.length == 6) {
            _codeFocusNode.unfocus();
          }
        },
      ),
    );
  }

  Widget _buildJoinButton() {
    return GestureDetector(
      onTap: _isJoining ? null : _joinSession,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _isJoining ? Colors.blue.shade200 : Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _isJoining
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Join',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
