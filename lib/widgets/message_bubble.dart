import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../screens/chat/image_viewer_screen.dart';
import '../screens/call/outgoing_call_screen.dart';
import '../services/call/call_service.dart';
import '../models/call.dart';

class MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String? senderName;
  final String time;
  final String? imageUrl;
  final String? audioUrl;
  final int? durationSeconds;
  final bool isSystem;

  const MessageBubble({
    super.key,
    required this.content,
    required this.isMe,
    this.senderName,
    required this.time,
    this.imageUrl,
    this.audioUrl,
    this.durationSeconds,
    this.isSystem = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (senderName != null)
                Text(
                  senderName!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (audioUrl != null) {
      return _AudioMessageBubble(
        audioUrl: audioUrl!,
        durationSeconds: durationSeconds,
        isMe: isMe,
        senderName: senderName,
        time: time,
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ImageViewerScreen(
                              imageUrl: imageUrl!,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 200,
                              height: 150,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              width: 200,
                              height: 100,
                              child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            );
                          },
                        ),
                      ),
                    ),
                  if (imageUrl != null && content.isNotEmpty)
                    const SizedBox(height: 6),
                  if (content.isNotEmpty)
                    Text(
                      content,
                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int? durationSeconds;
  final bool isMe;
  final String? senderName;
  final String time;

  const _AudioMessageBubble({
    required this.audioUrl,
    this.durationSeconds,
    required this.isMe,
    this.senderName,
    required this.time,
  });

  @override
  State<_AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<_AudioMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.audioUrl);
      _player.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _duration = duration);
        }
      });
      _player.positionStream.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });
      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (widget.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  widget.senderName!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (_isPlaying) {
                        await _player.pause();
                      } else {
                        await _player.play();
                      }
                    },
                    child: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: widget.isMe ? Colors.white : Colors.blue,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            activeTrackColor: widget.isMe ? Colors.white70 : Colors.blue,
                            inactiveTrackColor: widget.isMe ? Colors.white30 : Colors.blue[100],
                            thumbColor: widget.isMe ? Colors.white : Colors.blue,
                          ),
                          child: Slider(
                            value: _position.inMilliseconds.toDouble().clamp(
                              0,
                              _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                            ),
                            max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                            onChanged: (value) {
                              _player.seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isMe ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(widget.time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class CallMessageBubble extends StatelessWidget {
  final String callType;
  final String callStatus;
  final int? durationSeconds;
  final String time;
  final bool isMe;
  final String senderId;
  final String senderName;
  final String? chatId;
  final String? groupId;
  final List<String> members;

  const CallMessageBubble({
    super.key,
    required this.callType,
    required this.callStatus,
    this.durationSeconds,
    required this.time,
    required this.isMe,
    required this.senderId,
    required this.senderName,
    this.chatId,
    this.groupId,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final isMissed = callStatus == 'missed';
    final isVideo = callType == 'video';
    final icon = isVideo ? Icons.videocam : Icons.call;
    final iconColor = isMissed ? Colors.red : Colors.green;

    return Center(
      child: GestureDetector(
        onTap: isMissed ? () => _callBack(context) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isMissed ? Colors.red[50] : Colors.green[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMissed
                        ? (isVideo ? 'Missed video call' : 'Missed audio call')
                        : (isVideo ? 'Video call' : 'Audio call'),
                    style: TextStyle(
                      color: isMissed ? Colors.red : Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!isMissed && durationSeconds != null && durationSeconds! > 0)
                    Text(
                      _formatDuration(durationSeconds!),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              if (isMissed) ...[
                const SizedBox(width: 8),
                Icon(Icons.call, color: Colors.green, size: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _callBack(BuildContext context) async {
    final callService = CallService();
    final callTypeValue = callType == 'video' ? CallType.video : CallType.audio;

    final callId = await callService.startCall(
      chatId: chatId,
      groupId: groupId,
      createdBy: senderId,
      type: callTypeValue,
      members: members,
    );

    final callStream = callService.getCallStream(callId);
    final call = await callStream.firstWhere((c) => c != null);

    if (call == null || !context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutgoingCallScreen(
          call: call,
          callName: senderName,
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
