import 'package:flutter/material.dart';
import '../models/call.dart';
import '../services/call/call_manager.dart';
import '../screens/call/call_screen.dart';
import '../utils/time_format.dart';

class MiniCallBanner extends StatefulWidget {
  const MiniCallBanner({super.key});

  @override
  State<MiniCallBanner> createState() => _MiniCallBannerState();
}

class _MiniCallBannerState extends State<MiniCallBanner> {
  final _callManager = CallManager();

  @override
  void initState() {
    super.initState();
    _callManager.addListener(_onCallUpdate);
  }

  @override
  void dispose() {
    _callManager.removeListener(_onCallUpdate);
    super.dispose();
  }

  void _onCallUpdate() {
    if (mounted) setState(() {});
  }

  void _returnToCall() {
    final call = _callManager.activeCall;
    if (call == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: call.callId,
          callName: call.callName,
          callType: call.callType,
          members: call.members,
          createdBy: call.createdBy,
          isGroup: call.isGroup,
          chatId: call.chatId,
          groupId: call.groupId,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.15)
              : const Color(0xFFFE4EF0).withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFFFE4EF0),
          size: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final call = _callManager.activeCall;
    if (call == null) return const SizedBox.shrink();

    final isVideo = call.callType == CallType.video;

    return GestureDetector(
      onTap: _returnToCall,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D1B69), Color(0xFF1A0A2E)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
              ),
              child: Icon(
                isVideo ? Icons.videocam : Icons.call,
                color: const Color(0xFFFE4EF0),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    call.callName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        formatSeconds(_callManager.callDuration),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildControlButton(
              icon: _callManager.isMuted ? Icons.mic_off : Icons.mic,
              isActive: !_callManager.isMuted,
              onTap: () => _callManager.toggleMute(),
            ),
            const SizedBox(width: 6),
            if (isVideo) ...[
              _buildControlButton(
                icon: _callManager.isVideoOff
                    ? Icons.videocam_off
                    : Icons.videocam,
                isActive: !_callManager.isVideoOff,
                onTap: () => _callManager.toggleVideo(),
              ),
              const SizedBox(width: 6),
            ],
            _buildControlButton(
              icon: _callManager.isSpeakerOn
                  ? Icons.volume_up
                  : Icons.volume_down,
              isActive: true,
              onTap: () => _callManager.toggleSpeaker(),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _callManager.endActiveCall(),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _returnToCall,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_full,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
