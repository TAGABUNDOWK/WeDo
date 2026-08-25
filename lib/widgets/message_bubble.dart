import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/chat_theme.dart';
import '../screens/chat/image_viewer_screen.dart';
import '../screens/call/outgoing_call_screen.dart';
import '../services/call/call_service.dart';
import '../models/call.dart';
import '../models/event.dart';
import '../models/poll.dart';
import 'event_message_card.dart';
import 'poll_message_card.dart';

const _sentBubbleColor = Color(0xFFD9FDD3);
const _receivedBubbleColor = Color(0xFFFFFFFF);
const _textPrimary = Color(0xFF111B21);
const _textSecondary = Color(0xFF667781);
const _accent = Color(0xFF25D366);

class MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String? senderName;
  final String time;
  final String? imageUrl;
  final String? audioUrl;
  final int? durationSeconds;
  final bool isSystem;
  final ChatEvent? event;
  final ChatPoll? poll;
  final String? currentUid;
  final VoidCallback? onEventTap;
  final AppChatTheme? theme;

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
    this.event,
    this.poll,
    this.currentUid,
    this.onEventTap,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final sentBg = t?.sentBubble ?? _sentBubbleColor;
    final recvBg = t?.receivedBubble ?? _receivedBubbleColor;
    final txtPri = t?.textPrimary ?? _textPrimary;
    final txtSec = t?.textSecondary ?? _textSecondary;
    final accent = t?.accent ?? _accent;

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(8),
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
                    color: Color(0xFF856404),
                  ),
                ),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF856404),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (event != null) {
      final String resolvedUid = currentUid ?? '';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: EventMessageCard(
          event: event!,
          isMe: isMe,
          senderName: senderName ?? '',
          currentUid: resolvedUid,
          onTap: onEventTap,
          onInfoTap: onEventTap,
        ),
      );
    }

    if (poll != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 48),
        child: PollMessageCard(
          key: ValueKey(poll!.id),
          poll: poll!,
          isMe: isMe,
          senderName: senderName ?? '',
          currentUid: currentUid ?? '',
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
        theme: t,
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 60 : 8,
          right: isMe ? 8 : 60,
          top: 2,
          bottom: 2,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderName != null && !isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? sentBg : recvBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
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
                          width: 240,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 240,
                              height: 160,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              width: 240,
                              height: 100,
                              child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            );
                          },
                        ),
                      ),
                    ),
                  if (imageUrl != null && content.isNotEmpty)
                    const SizedBox(height: 4),
                  if (content.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            content,
                            style: TextStyle(
                              fontSize: 15,
                              color: txtPri,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: txtSec,
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
    );
  }
}

class _AudioMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int? durationSeconds;
  final bool isMe;
  final String? senderName;
  final String time;
  final AppChatTheme? theme;

  const _AudioMessageBubble({
    required this.audioUrl,
    this.durationSeconds,
    required this.isMe,
    this.senderName,
    required this.time,
    this.theme,
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
    final t = widget.theme;
    final sentBg = t?.sentBubble ?? _sentBubbleColor;
    final recvBg = t?.receivedBubble ?? _receivedBubbleColor;
    final txtPri = t?.textPrimary ?? _textPrimary;
    final txtSec = t?.textSecondary ?? _textSecondary;
    final accent = t?.accent ?? _accent;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: widget.isMe ? 60 : 8,
          right: widget.isMe ? 8 : 60,
          top: 2,
          bottom: 2,
        ),
        child: Column(
          crossAxisAlignment:
              widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (widget.senderName != null && !widget.isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  widget.senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isMe ? sentBg : recvBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(widget.isMe ? 12 : 4),
                  bottomRight: Radius.circular(widget.isMe ? 4 : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
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
                      color: widget.isMe
                          ? txtPri.withValues(alpha: 0.7)
                          : accent,
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
                            activeTrackColor: widget.isMe
                                ? txtPri.withValues(alpha: 0.4)
                                : accent,
                            inactiveTrackColor: widget.isMe
                                ? txtPri.withValues(alpha: 0.15)
                                : accent.withValues(alpha: 0.2),
                            thumbColor: widget.isMe
                                ? txtPri.withValues(alpha: 0.6)
                                : accent,
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
                          color: widget.isMe
                              ? txtPri.withValues(alpha: 0.5)
                              : txtSec,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                widget.time,
                style: TextStyle(fontSize: 11, color: txtSec),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CallMessageBubble extends StatefulWidget {
  final String callType;
  final String callStatus;
  final int? durationSeconds;
  final String time;
  final bool isMe;
  final String senderId;
  final String senderName;
  final String currentUserId;
  final String? chatId;
  final String? groupId;
  final List<String> members;
  final AppChatTheme? theme;

  const CallMessageBubble({
    super.key,
    required this.callType,
    required this.callStatus,
    this.durationSeconds,
    required this.time,
    required this.isMe,
    required this.senderId,
    required this.senderName,
    required this.currentUserId,
    this.chatId,
    this.groupId,
    required this.members,
    this.theme,
  });

  @override
  State<CallMessageBubble> createState() => _CallMessageBubbleState();
}

class _CallMessageBubbleState extends State<CallMessageBubble> {
  bool _isCalling = false;

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isMissed = widget.callStatus == 'missed';
    final isDeclined = widget.callStatus == 'declined';
    final isCancelled = widget.callStatus == 'cancelled';
    final isVideo = widget.callType == 'video';
    final icon = isVideo ? Icons.videocam : Icons.call;
    final accent = widget.theme?.accent ?? _accent;
    final txtSec = widget.theme?.textSecondary ?? _textSecondary;

    final hasStatus = isMissed || isDeclined || isCancelled;
    final callLabel = isVideo ? 'Video Call' : 'Voice Call';
    final statusLabel = isMissed
        ? 'Missed'
        : isDeclined
            ? 'Declined'
            : isCancelled
                ? 'Cancelled'
                : '';

    final durationText = !hasStatus &&
            widget.durationSeconds != null &&
            widget.durationSeconds! > 0
        ? _formatDuration(widget.durationSeconds!)
        : null;

    return Center(
      child: GestureDetector(
        onTap: (isMissed || isDeclined) && !_isCalling ? () => _callBack() : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hasStatus
                ? const Color(0xFFFFF0F0)
                : const Color(0xFFF0FFF4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: hasStatus ? const Color(0xFFE53935) : accent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasStatus ? '$statusLabel $callLabel' : callLabel,
                    style: TextStyle(
                      color: hasStatus ? const Color(0xFFE53935) : accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (durationText != null) ...[
                    Text(
                      ' \u2022 $durationText',
                      style: TextStyle(
                        color: txtSec,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if ((isMissed || isDeclined) && !_isCalling) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.call,
                      color: accent,
                      size: 13,
                    ),
                  ],
                  if (_isCalling) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                widget.time,
                style: TextStyle(
                  fontSize: 11,
                  color: txtSec,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callBack() async {
    if (_isCalling) return;
    setState(() => _isCalling = true);

    try {
      final callService = CallService();
      final callTypeValue =
          widget.callType == 'video' ? CallType.video : CallType.audio;

      final callId = await callService.startCall(
        chatId: widget.chatId,
        groupId: widget.groupId,
        createdBy: widget.currentUserId,
        type: callTypeValue,
        members: widget.members,
      );

      final call = await callService
          .getCallStream(callId)
          .firstWhere((c) => c != null)
          .timeout(const Duration(seconds: 15));

      if (!mounted || call == null) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OutgoingCallScreen(
            call: call,
            callName: widget.senderName,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Call back failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start call. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalling = false);
    }
  }
}
