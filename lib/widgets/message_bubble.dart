import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/chat_theme.dart';
import '../utils/time_format.dart';
import '../screens/chat/image_viewer_screen.dart';
import '../screens/call/outgoing_call_screen.dart';
import '../services/call/call_service.dart';
import '../models/call.dart';
import '../models/event.dart';
import '../models/poll.dart';
import 'event_message_card.dart';
import 'poll_message_card.dart';
import 'reaction_picker.dart';

const _sentBubbleColor = Color(0xFFD9FDD3);
const _receivedBubbleColor = Color(0xFFFFFFFF);
const _textPrimary = Color(0xFF111B21);
const _textSecondary = Color(0xFF667781);
const _accent = Color(0xFF25D366);

class MessageBubble extends StatefulWidget {
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
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final DateTime? createdAt;
  final bool edited;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleteForEveryone;
  final VoidCallback? onDeleteForMe;
  final String? senderPhotoUrl;
  final bool isRead;
  final bool showReadAvatar;
  final String? readAvatarUrl;
  final VoidCallback? onReply;
  final Map<String, dynamic>? reactions;
  final ValueChanged<String>? onReact;
  final String? replyToContent;
  final String? replyToSender;

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
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.createdAt,
    this.edited = false,
    this.onEdit,
    this.onDeleteForEveryone,
    this.onDeleteForMe,
    this.senderPhotoUrl,
    this.isRead = false,
    this.showReadAvatar = false,
    this.readAvatarUrl,
    this.onReply,
    this.reactions,
    this.onReact,
    this.replyToContent,
    this.replyToSender,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showDetails = false;

  void _toggleDetails() {
    if (widget.isSystem || widget.event != null || widget.poll != null) return;
    setState(() => _showDetails = !_showDetails);
  }

  void _showContextMenu() {
    if (widget.isSystem || widget.event != null || widget.poll != null) return;

    final hasEdit = widget.isMe && widget.onEdit != null;
    final hasDeleteEveryone = widget.isMe && widget.onDeleteForEveryone != null;
    final hasDeleteMe = widget.onDeleteForMe != null;
    final hasReply = widget.onReply != null;
    final hasReact = widget.onReact != null;
    final t = widget.theme;

    showModalBottomSheet(
      context: context,
      backgroundColor: t?.composerBackground ?? Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: t?.divider ?? Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (hasReact)
              ListTile(
                leading: Icon(Icons.emoji_emotions_outlined, size: 22, color: t?.textSecondary),
                title: Text('React', style: TextStyle(fontSize: 15, color: t?.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReactionPicker();
                },
              ),
            if (hasReply)
              ListTile(
                leading: Icon(Icons.reply, size: 22, color: t?.textSecondary),
                title: Text('Reply', style: TextStyle(fontSize: 15, color: t?.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onReply?.call();
                },
              ),
            if (hasEdit)
              ListTile(
                leading: Icon(Icons.edit_outlined, size: 22, color: t?.textSecondary),
                title: Text('Edit', style: TextStyle(fontSize: 15, color: t?.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onEdit?.call();
                },
              ),
            if (hasDeleteEveryone)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red, size: 22),
                title: const Text('Delete for everyone', style: TextStyle(color: Colors.red, fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDeleteForEveryone?.call();
                },
              ),
            if (hasDeleteMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                title: const Text('Delete for me', style: TextStyle(color: Colors.red, fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDeleteForMe?.call();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker() {
    final currentReaction = widget.reactions != null
        ? widget.reactions![widget.currentUid] as String?
        : null;
    ReactionPicker.show(
      context,
      currentReaction: currentReaction,
      theme: widget.theme,
      onReact: (emoji) {
        if (currentReaction == emoji) {
          widget.onReact?.call('');
        } else {
          widget.onReact?.call(emoji);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final sentBg = t?.sentBubble ?? _sentBubbleColor;
    final recvBg = t?.receivedBubble ?? _receivedBubbleColor;
    final txtPri = t?.textPrimary ?? _textPrimary;
    final txtSec = t?.textSecondary ?? _textSecondary;
    final accent = t?.accent ?? _accent;

    if (widget.isSystem) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 40),
          child: Text(
            widget.content,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: txtSec,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (widget.event != null) {
      final String resolvedUid = widget.currentUid ?? '';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: EventMessageCard(
          event: widget.event!,
          isMe: widget.isMe,
          senderName: widget.senderName ?? '',
          currentUid: resolvedUid,
          onTap: widget.onEventTap,
          onInfoTap: widget.onEventTap,
        ),
      );
    }

    if (widget.poll != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 48),
        child: PollMessageCard(
          key: ValueKey(widget.poll!.id),
          poll: widget.poll!,
          isMe: widget.isMe,
          senderName: widget.senderName ?? '',
          currentUid: widget.currentUid ?? '',
        ),
      );
    }

    if (widget.audioUrl != null) {
      final showAvatarAudio = !widget.isMe && widget.isFirstInGroup;
      final hasPhotoAudio = widget.senderPhotoUrl != null && widget.senderPhotoUrl!.isNotEmpty;
      final senderInitialAudio = (widget.senderName ?? '?').substring(0, 1).toUpperCase();

      return GestureDetector(
        onTap: _toggleDetails,
        onLongPress: _showContextMenu,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: widget.isMe ? 48 : 0,
                right: widget.isMe ? 0 : 48,
                top: widget.isFirstInGroup ? 6 : 1,
                bottom: widget.isLastInGroup ? 1 : 0,
              ),
              child: Row(
                mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showAvatarAudio)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 2),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: accent,
                        backgroundImage: hasPhotoAudio ? NetworkImage(widget.senderPhotoUrl!) : null,
                        child: hasPhotoAudio ? null : Text(
                          senderInitialAudio,
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else if (!widget.isMe)
                    const SizedBox(width: 34),
                  Flexible(
                    child: _AudioMessageBubble(
                      audioUrl: widget.audioUrl!,
                      durationSeconds: widget.durationSeconds,
                      isMe: widget.isMe,
                      senderName: widget.senderName,
                      time: widget.time,
                      theme: t,
                      isFirstInGroup: widget.isFirstInGroup,
                      isLastInGroup: widget.isLastInGroup,
                    ),
                  ),
                  if (widget.isMe)
                    SizedBox(
                      width: 24,
                      child: widget.isLastInGroup
                          ? Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 2),
                              child: Icon(
                                widget.isRead ? Icons.done_all : Icons.done,
                                size: 16,
                                color: widget.isRead ? const Color(0xFF53BDEB) : txtSec,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
            if (widget.showReadAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 48, top: 2, bottom: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: accent,
                      backgroundImage: widget.readAvatarUrl != null &&
                              widget.readAvatarUrl!.isNotEmpty
                          ? NetworkImage(widget.readAvatarUrl!)
                          : null,
                      child: widget.readAvatarUrl == null ||
                              widget.readAvatarUrl!.isEmpty
                          ? const Icon(Icons.person, size: 10, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              ),
            if (_showDetails && widget.createdAt != null)
              Padding(
                padding: EdgeInsets.only(
                  left: widget.isMe ? 72 : 40,
                  right: widget.isMe ? 40 : 72,
                  top: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatFullDateTime(widget.createdAt),
                      style: TextStyle(fontSize: 11, color: txtSec),
                    ),
                    if (widget.edited)
                      Text(' (edited)', style: TextStyle(fontSize: 11, color: txtSec)),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    final showAvatar = !widget.isMe && widget.isFirstInGroup;
    final hasPhoto = widget.senderPhotoUrl != null && widget.senderPhotoUrl!.isNotEmpty;
    final senderInitial = (widget.senderName ?? '?').substring(0, 1).toUpperCase();

    return GestureDetector(
      onTap: _toggleDetails,
      onLongPress: _showContextMenu,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: widget.isMe ? 48 : 0,
              right: widget.isMe ? 0 : 48,
              top: widget.isFirstInGroup ? 4 : 1,
              bottom: widget.isLastInGroup ? 8 : 0,
            ),
            child: Row(
              mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 2),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: accent,
                      backgroundImage: hasPhoto ? NetworkImage(widget.senderPhotoUrl!) : null,
                      child: hasPhoto ? null : Text(
                        senderInitial,
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else if (!widget.isMe)
                  const SizedBox(width: 34),
                Flexible(
                  child: Column(
                    crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (widget.senderName != null && !widget.isMe && widget.isFirstInGroup)
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: widget.isMe ? sentBg : recvBg,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
                                bottomRight: Radius.circular(widget.isMe ? 4 : 18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.replyToContent != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border(
                                        left: BorderSide(
                                          color: widget.isMe ? sentBg.withValues(alpha: 0.8) : accent.withValues(alpha: 0.6),
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (widget.replyToSender != null)
                                          Text(
                                            widget.replyToSender!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: accent,
                                            ),
                                          ),
                                        Text(
                                          widget.replyToContent!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: txtSec,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.imageUrl != null)
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ImageViewerScreen(
                                            imageUrl: widget.imageUrl!,
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        widget.imageUrl!,
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
                                if (widget.imageUrl != null && widget.content.isNotEmpty)
                                  const SizedBox(height: 4),
                                if (widget.content.isNotEmpty)
                                  Text(
                                    widget.content,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: txtPri,
                                      height: 1.3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.reactions != null && widget.reactions!.isNotEmpty)
                            Positioned(
                              bottom: -8,
                              right: widget.isMe ? 4 : null,
                              left: widget.isMe ? null : 4,
                              child: _buildReactionBadge(widget.reactions!, widget.currentUid, accent),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.isMe)
                  SizedBox(
                    width: 24,
                    child: widget.isLastInGroup
                        ? Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 2),
                            child: Icon(
                              widget.isRead ? Icons.done_all : Icons.done,
                              size: 16,
                              color: widget.isRead ? const Color(0xFF53BDEB) : txtSec,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          if (widget.isLastInGroup)
            Padding(
              padding: EdgeInsets.only(
                left: widget.isMe ? 48 : 40,
                right: widget.isMe ? 40 : 48,
                top: 2,
                bottom: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isMe) ...[
                    Text(
                      widget.time,
                      style: TextStyle(fontSize: 11, color: txtSec),
                    ),
                  ] else ...[
                    Text(
                      widget.time,
                      style: TextStyle(fontSize: 11, color: txtSec),
                    ),
                  ],
                ],
              ),
            ),
          if (widget.showReadAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 48, top: 2, bottom: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: accent,
                    backgroundImage: widget.readAvatarUrl != null &&
                            widget.readAvatarUrl!.isNotEmpty
                        ? NetworkImage(widget.readAvatarUrl!)
                        : null,
                    child: widget.readAvatarUrl == null ||
                            widget.readAvatarUrl!.isEmpty
                        ? const Icon(Icons.person, size: 10, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),
          if (_showDetails && widget.createdAt != null)
            Padding(
              padding: EdgeInsets.only(
                left: widget.isMe ? 72 : 40,
                right: widget.isMe ? 40 : 72,
                top: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatFullDateTime(widget.createdAt),
                    style: TextStyle(fontSize: 11, color: txtSec),
                  ),
                  if (widget.edited)
                    Text(' (edited)', style: TextStyle(fontSize: 11, color: txtSec)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReactionBadge(Map<String, dynamic> reactions, String? currentUid, Color accent) {
    final Map<String, int> emojiCounts = {};
    for (final emoji in reactions.values) {
      final e = emoji as String;
      emojiCounts[e] = (emojiCounts[e] ?? 0) + 1;
    }

    final isOwn = reactions.containsKey(currentUid);
    final ownEmoji = isOwn ? reactions[currentUid] as String : null;
    final displayEmoji = ownEmoji ?? emojiCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final count = emojiCounts[displayEmoji] ?? 1;
    final isOwnDisplay = isOwn && ownEmoji == displayEmoji;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isOwnDisplay
            ? accent.withValues(alpha: 0.18)
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOwnDisplay
              ? accent.withValues(alpha: 0.4)
              : Theme.of(context).dividerColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(displayEmoji, style: const TextStyle(fontSize: 14)),
          if (count > 1) ...[
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                color: isOwnDisplay ? accent : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const _AudioMessageBubble({
    required this.audioUrl,
    this.durationSeconds,
    required this.isMe,
    this.senderName,
    required this.time,
    this.theme,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  @override
  State<_AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<_AudioMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.audioUrl);
      _durationSub = _player.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _duration = duration);
        }
      });
      _positionSub = _player.positionStream.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });
      _playerStateSub = _player.playerStateStream.listen((state) {
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
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
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
          top: widget.isFirstInGroup ? 2 : 0,
          bottom: widget.isLastInGroup ? 2 : 0,
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
                        formatDuration(_duration),
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
            if (widget.isLastInGroup)
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
  final bool isFirstInGroup;
  final bool isLastInGroup;

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
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  @override
  State<CallMessageBubble> createState() => _CallMessageBubbleState();
}

class _CallMessageBubbleState extends State<CallMessageBubble> {
  bool _isCalling = false;

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
        ? formatSeconds(widget.durationSeconds!)
        : null;

    return Center(
      child: GestureDetector(
        onTap: (isMissed || isDeclined) && !_isCalling ? () => _callBack() : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasStatus ? '$statusLabel $callLabel' : callLabel,
                    style: TextStyle(
                      color: hasStatus ? const Color(0xFFE53935) : accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (durationText != null) ...[
                    Text(
                      ' \u2022 $durationText',
                      style: TextStyle(
                        color: txtSec,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if ((isMissed || isDeclined) && !_isCalling) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.call,
                      color: accent,
                      size: 12,
                    ),
                  ],
                  if (_isCalling) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.isLastInGroup)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.time,
                    style: TextStyle(
                      fontSize: 10,
                      color: txtSec,
                    ),
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
