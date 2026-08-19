import 'package:flutter/material.dart';
import '../../models/call.dart';
import '../../services/call/call_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final Call call;
  final String callerName;

  const IncomingCallScreen({
    super.key,
    required this.call,
    required this.callerName,
  });

  @override
  Widget build(BuildContext context) {
    final callService = CallService();
    final isVideo = call.type == CallType.video;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A2E),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(
              isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
              child: Text(
                callerName.isNotEmpty
                    ? callerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (call.groupId != null)
              const Text(
                'Group Call',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            const Spacer(flex: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.call_end,
                  label: 'Decline',
                  color: Colors.red,
                  onTap: () {
                    callService.endCall(call.id);
                    Navigator.of(context).pop();
                  },
                ),
                _buildActionButton(
                  icon: isVideo ? Icons.videocam : Icons.call,
                  label: 'Accept',
                  color: Colors.green,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          callId: call.id,
                          callName: callerName,
                          callType: call.type,
                          members: call.members,
                          isGroup: call.groupId != null,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
