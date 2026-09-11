import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/call.dart';
import '../../../models/event.dart';
import '../../../models/chat_theme.dart';
import '../../../models/group_chat.dart';
import '../../../models/message.dart';
import '../../../models/poll.dart';
import '../../../services/group/group_service.dart';
import '../../../services/event/event_service.dart';
import '../../../services/poll/poll_service.dart';
import '../../../services/call/call_service.dart';
import '../../../services/user_cache.dart';
import '../../../services/theme/chat_theme_resolver.dart';
import '../../../utils/time_format.dart';
import '../../../widgets/message_bubble.dart';
import '../../../widgets/call_button.dart';
import '../../../widgets/date_separator.dart';
import '../../../widgets/invite_message_card.dart';
import '../../../widgets/tri_race_invite_message_card.dart';
import '../../../widgets/group_invite_message_card.dart';
import '../../../widgets/composer_option.dart';
import '../../../widgets/audio_recorder_button.dart';
import '../../../widgets/swipe_reply_wrapper.dart';
import '../../call/outgoing_call_screen.dart';
import '../event/create_event_screen.dart';
import '../event/event_detail_screen.dart';
import '../poll/create_poll_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _groupService = GroupService();
  final _callService = CallService();
  final _eventService = EventService();
  final _pollService = PollService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _imagePicker = ImagePicker();
  String _groupName = '';
  String? _groupPhotoUrl;
  Map<String, String> _nicknames = {};
  final Map<String, String> _memberPhotos = {};
  final Map<String, String> _memberNames = {};
  final Map<String, String> _memberAvatarAssets = {};
  List<String> _members = [];
  late Stream<GroupChat?> _groupStream;
  bool _isUploading = false;
  final Map<String, ChatEvent> _events = {};
  final Map<String, ChatPoll> _polls = {};
  AppChatTheme _chatTheme = ChatThemeResolver.defaultTheme;
  int _newMessageCount = 0;
  bool _isAtBottom = true;
  int _lastMessageCount = 0;
  late Stream<List<ChatMessage>> _messagesStream;
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _groupStream = _groupService.getGroupStream(widget.groupId);
    _messagesStream = _groupService.getMessagesStream(widget.groupId);
    _loadGroupInfo();
    if (_currentUser != null) {
      _groupService.markMessagesAsRead(widget.groupId, _currentUser.uid);
    }
    _scrollCtrl.addListener(_onScroll);
  }

  Future<void> _loadGroupInfo() async {
    final group = await _groupService.getGroup(widget.groupId);
    final nicknames = await _groupService.getMemberNicknames(widget.groupId);
    final theme = await ChatThemeResolver().resolve(
      widget.groupId,
      'group_chats',
    );
    if (group != null && mounted) {
      final members = List<String>.from(group.members);
      setState(() {
        _groupName = group.name;
        _groupPhotoUrl = group.photoUrl;
        _nicknames = nicknames;
        _members = members;
        _chatTheme = theme;
      });
      _preloadMemberProfiles(members);
    }
  }

  Future<void> _preloadMemberProfiles(List<String> memberUids) async {
    final cache = UserCache();
    final futures = memberUids.map((uid) async {
      final user = await cache.getUser(uid);
      if (user != null && mounted) {
        if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
          _memberPhotos[uid] = user.photoUrl!;
        }
        if (user.avatarAsset != null && user.avatarAsset!.isNotEmpty) {
          _memberAvatarAssets[uid] = user.avatarAsset!;
        }
        _memberNames[uid] = user.displayName.isNotEmpty
            ? user.displayName
            : user.username;
      }
    }).toList();
    await Future.wait(futures);
    if (mounted) setState(() {});
  }

  Future<void> _loadMemberPhoto(String uid) async {
    if (_memberPhotos.containsKey(uid) && _memberAvatarAssets.containsKey(uid)) return;
    final cache = UserCache();
    final user = await cache.getUser(uid);
    if (user != null && mounted) {
      if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
        _memberPhotos[uid] = user.photoUrl!;
      }
      if (user.avatarAsset != null && user.avatarAsset!.isNotEmpty) {
        _memberAvatarAssets[uid] = user.avatarAsset!;
      }
      if (user.displayName.isNotEmpty) {
        _memberNames[uid] = user.displayName;
      } else if (user.username.isNotEmpty) {
        _memberNames[uid] = user.username;
      }
      setState(() {});
    }
  }

  Future<void> _loadEventPollData(ChatMessage msg) async {
    if (msg.refId == null) return;
    if (msg.type == MessageType.event && !_events.containsKey(msg.refId)) {
      final event = await _eventService.getEvent(
        msg.refId!,
        groupId: widget.groupId,
      );
      if (event != null && mounted) {
        setState(() => _events[msg.refId!] = event);
      }
    } else if (msg.type == MessageType.poll && !_polls.containsKey(msg.refId)) {
      final poll = await _pollService.getPoll(
        msg.refId!,
        groupId: widget.groupId,
      );
      if (poll != null && mounted) {
        setState(() => _polls[msg.refId!] = poll);
      }
    }
  }

  String _getDisplayName(String uid, String fallback) {
    return _nicknames[uid] ?? _memberNames[uid] ?? fallback;
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final currentScroll = _scrollCtrl.offset;
    final atBottom = currentScroll < 80;
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
      if (atBottom) {
        setState(() => _newMessageCount = 0);
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() => _newMessageCount = 0);
  }

  void _sendMessage() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    _groupService.sendMessage(
      groupId: widget.groupId,
      senderId: _currentUser.uid,
      senderName: _getDisplayName(
        _currentUser.uid,
        _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
      ),
      text: text,
      replyTo: _replyingTo?.id,
      replyToContent: _replyingTo?.content,
      replyToSender: _replyingTo?.senderName,
    );

    _messageCtrl.clear();
    setState(() => _replyingTo = null);
  }

  void _editMessage(ChatMessage msg) {
    final editCtrl = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editCtrl,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Edit message...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newContent = editCtrl.text.trim();
              if (newContent.isNotEmpty && newContent != msg.content) {
                _groupService.editMessage(
                  groupId: widget.groupId,
                  messageId: msg.id,
                  newContent: newContent,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteMessageForEveryone(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete for everyone?'),
        content: const Text(
          'This message will be deleted for everyone in this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _groupService.deleteMessage(
                groupId: widget.groupId,
                messageId: msg.id,
                uid: _currentUser!.uid,
                forEveryone: true,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteMessageForMe(ChatMessage msg) {
    _groupService.deleteMessage(
      groupId: widget.groupId,
      messageId: msg.id,
      uid: _currentUser!.uid,
      forEveryone: false,
    );
  }

  void _startReply(ChatMessage msg) {
    setState(() => _replyingTo = msg);
    _messageCtrl.clear();
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _toggleReaction(ChatMessage msg, String emoji) {
    final user = _currentUser;
    if (user == null) return;
    if (emoji.isEmpty) {
      _groupService.removeReaction(
        groupId: widget.groupId,
        messageId: msg.id,
        uid: user.uid,
      );
    } else {
      _groupService.addReaction(
        groupId: widget.groupId,
        messageId: msg.id,
        uid: user.uid,
        emoji: emoji,
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked == null || _currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      await _groupService.sendImageMessage(
        groupId: widget.groupId,
        senderId: _currentUser.uid,
        senderName: _getDisplayName(
          _currentUser.uid,
          _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
        ),
        imageFile: File(picked.path),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _onAudioRecorded(File audioFile, int durationSeconds) async {
    if (_currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      await _groupService.sendAudioMessage(
        groupId: widget.groupId,
        senderId: _currentUser.uid,
        senderName: _getDisplayName(
          _currentUser.uid,
          _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
        ),
        audioFile: audioFile,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _openGroupInfo() async {
    await Navigator.pushNamed(
      context,
      '/group-info',
      arguments: widget.groupId,
    );
    _loadGroupInfo();
  }

  Future<void> _startCall(CallType type) async {
    if (_currentUser == null) return;

    final group = await _groupService.getGroup(widget.groupId);
    if (group == null) return;

    final members = List<String>.from(group.members);

    final callId = await _callService.startCall(
      groupId: widget.groupId,
      createdBy: _currentUser.uid,
      type: type,
      members: members,
    );

    if (!mounted) return;

    final callStream = _callService.getCallStream(callId);
    final call = await callStream.first;

    if (!mounted || call == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutgoingCallScreen(call: call, callName: _groupName),
      ),
    );
  }

  void _showComposerMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add to chat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  ComposerOption(
                    icon: Icons.photo_outlined,
                    label: 'Photo',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage();
                    },
                  ),
                  ComposerOption(
                    icon: Icons.event_outlined,
                    label: 'Event',
                    color: Colors.teal,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateEventScreen(groupId: widget.groupId),
                        ),
                      );
                      if (result == true) _loadGroupInfo();
                    },
                  ),
                  ComposerOption(
                    icon: Icons.poll_outlined,
                    label: 'Poll',
                    color: Colors.deepPurple,
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreatePollScreen(groupId: widget.groupId),
                        ),
                      );
                      if (result == true) _loadGroupInfo();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _chatTheme;
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      body: Stack(
        children: [
          // ── Background: base + dotted grid + overlays ──
          Container(color: const Color(0xFF190831)),
          const _ChatDottedGrid(),
          Positioned(
            top: 60,
            left: -300,
            child: Transform.rotate(
              angle: -0.285,
              child: Opacity(
                opacity: 0.05,
                child: Image.asset(
                  'assets/images/Ears-overlay1.png',
                  width: 800,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            // Offset by the keyboard inset so the overlay stays pinned to
            // the physical screen bottom instead of riding up with it.
            bottom: -10 - MediaQuery.of(context).viewInsets.bottom,
            right: -255,
            child: Transform.rotate(
              angle: -0.3454,
              child: Opacity(
                opacity: 0.05,
                child: Image.asset(
                  'assets/images/Eyes-overlay1.png',
                  width: 750,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Rounded glass header ──
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                            GestureDetector(
                              onTap: () => Navigator.maybePop(context),
                              child: Image.asset(
                                'assets/icons/back-nav.png',
                                width: 30,
                                height: 30,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                            if (_newMessageCount > 0) ...[
                              const SizedBox(width: 8),
                              const _HeartbeatDot(),
                              const SizedBox(width: 4),
                              const Text(
                                'NEW',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _openGroupInfo,
                              behavior: HitTestBehavior.opaque,
                              child: Tooltip(
                                message: 'Group info',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 80),
                                  child: StreamBuilder<GroupChat?>(
                                stream: _groupStream,
                                builder: (context, snapshot) {
                                  final group = snapshot.data;
                                  final photoUrl =
                                      group?.photoUrl ?? _groupPhotoUrl;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        key: ValueKey(photoUrl),
                                        radius: 16,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.2),
                                        backgroundImage: photoUrl != null &&
                                                photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        child: photoUrl == null ||
                                                photoUrl.isEmpty
                                            ? const Icon(
                                                Icons.group,
                                                color: Colors.white,
                                                size: 18,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          group?.name ?? _groupName,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                            CallButtons(
                              chatId: widget.groupId,
                              isGroup: true,
                              onStartAudioCall: () => _startCall(CallType.audio),
                              onStartVideoCall: () => _startCall(CallType.video),
                            ),
                          ],
                        ),
                      ),
                      ],
                    ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isUploading)
                const LinearProgressIndicator(
                    backgroundColor: Colors.transparent),
              Expanded(
                child: Stack(
                  children: [
                    StreamBuilder<List<ChatMessage>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data ?? [];
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            'No messages yet',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.6)),
                          ),
                        );
                      }

                      final newMessageCount =
                          messages.length - _lastMessageCount;
                      if (newMessageCount > 0) {
                        _lastMessageCount = messages.length;
                        if (_isAtBottom) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
                          });
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(
                                () => _newMessageCount += newMessageCount,
                              );
                            }
                          });
                        }
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        for (final m in messages) {
                          if ((m.type == MessageType.event ||
                                  m.type == MessageType.poll) &&
                              m.refId != null) {
                            _loadEventPollData(m);
                          }
                        }
                      });

                      return ListView.builder(
                        reverse: true,
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderId == _currentUser?.uid;
                          final isSystem = msg.type == MessageType.system;

                          final sameSenderAsNextOlder =
                              index + 1 < messages.length &&
                              messages[index + 1].senderId == msg.senderId &&
                              isSameDay(
                                msg.createdAt,
                                messages[index + 1].createdAt,
                              );
                          final sameSenderAsPrevNewer =
                              index - 1 >= 0 &&
                              messages[index - 1].senderId == msg.senderId &&
                              isSameDay(
                                msg.createdAt,
                                messages[index - 1].createdAt,
                              );
                          final isFirstInGroup = !sameSenderAsNextOlder;
                          final isLastInGroup = !sameSenderAsPrevNewer;

                          final showDateSeparator =
                              index == 0 ||
                              !isSameDay(
                                messages[index].createdAt,
                                messages[index - 1].createdAt,
                              );

                          Widget buildMessage() {
                            if (isSystem) {
                              return MessageBubble(
                                content: msg.content,
                                isMe: false,
                                senderName: msg.senderName.isNotEmpty
                                    ? msg.senderName
                                    : null,
                                time: formatChatTime(msg.createdAt),
                                isSystem: true,
                                theme: t,
                                isFirstInGroup: isFirstInGroup,
                                isLastInGroup: isLastInGroup,
                                createdAt: msg.createdAt,
                              );
                            }

                            if (msg.type == MessageType.event &&
                                msg.refId != null) {
                              final evt = _events[msg.refId];
                              return MessageBubble(
                                content: msg.content,
                                isMe: isMe,
                                senderName: _getDisplayName(
                                  msg.senderId,
                                  msg.senderName,
                                ),
                                time: formatChatTime(msg.createdAt),
                                event: evt,
                                currentUid: _currentUser?.uid,
                                theme: t,
                                onEventTap: evt != null
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EventDetailScreen(
                                              eventId: evt.id,
                                              groupId: widget.groupId,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                              );
                            }

                            if (msg.type == MessageType.poll &&
                                msg.refId != null) {
                              return MessageBubble(
                                content: msg.content,
                                isMe: isMe,
                                senderName: isMe
                                    ? null
                                    : _getDisplayName(
                                        msg.senderId,
                                        msg.senderName,
                                      ),
                                time: formatChatTime(msg.createdAt),
                                poll: _polls[msg.refId],
                                currentUid: _currentUser?.uid,
                                theme: t,
                              );
                            }

                            final displayName = _getDisplayName(
                              msg.senderId,
                              msg.senderName,
                            );

                            if (!isMe &&
                                !_memberPhotos.containsKey(msg.senderId)) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _loadMemberPhoto(msg.senderId),
                              );
                            }

                          if (msg.type == MessageType.image &&
                              msg.imageUrl != null) {
                            return MessageBubble(
                              content: msg.content,
                              imageUrl: msg.imageUrl,
                              isMe: isMe,
                              senderName: isMe
                                  ? _ownDisplayName()
                                  : displayName,
                              time: formatChatTime(msg.createdAt),
                              theme: t,
                              isFirstInGroup: isFirstInGroup,
                              isLastInGroup: isLastInGroup,
                              createdAt: msg.createdAt,
                              edited: msg.edited,
                              onEdit: isMe ? () => _editMessage(msg) : null,
                              onDeleteForEveryone: isMe
                                  ? () => _deleteMessageForEveryone(msg)
                                  : null,
                              onDeleteForMe: () => _deleteMessageForMe(msg),
                              senderPhotoUrl: !isMe
                                  ? (_memberPhotos[msg.senderId]?.isNotEmpty == true ? _memberPhotos[msg.senderId] : null)
                                  : null,
                              senderAvatarAsset: !isMe
                                  ? _memberAvatarAssets[msg.senderId]
                                  : null,
                              isRead: isMe && msg.isRead,
                              currentUid: _currentUser?.uid,
                              onReply: () => _startReply(msg),
                              onReact: (emoji) => _toggleReaction(msg, emoji),
                              reactions: msg.reactions,
                              replyToContent: msg.replyToContent,
                              replyToSender: msg.replyToSender,
                            );
                          }

                          if (msg.type == MessageType.audio &&
                              msg.audioUrl != null) {
                            return MessageBubble(
                              content: msg.content,
                              audioUrl: msg.audioUrl,
                              durationSeconds: msg.durationSeconds,
                              isMe: isMe,
                              senderName: isMe
                                  ? _ownDisplayName()
                                  : displayName,
                              time: formatChatTime(msg.createdAt),
                              theme: t,
                              isFirstInGroup: isFirstInGroup,
                              isLastInGroup: isLastInGroup,
                              createdAt: msg.createdAt,
                              edited: msg.edited,
                              onEdit: isMe ? () => _editMessage(msg) : null,
                              onDeleteForEveryone: isMe
                                  ? () => _deleteMessageForEveryone(msg)
                                  : null,
                              onDeleteForMe: () => _deleteMessageForMe(msg),
                              senderPhotoUrl: !isMe
                                  ? (_memberPhotos[msg.senderId]?.isNotEmpty == true ? _memberPhotos[msg.senderId] : null)
                                  : null,
                              senderAvatarAsset: !isMe
                                  ? _memberAvatarAssets[msg.senderId]
                                  : null,
                              isRead: isMe && msg.isRead,
                              currentUid: _currentUser?.uid,
                              onReply: () => _startReply(msg),
                              onReact: (emoji) => _toggleReaction(msg, emoji),
                              reactions: msg.reactions,
                              replyToContent: msg.replyToContent,
                              replyToSender: msg.replyToSender,
                            );
                          }

                            if (msg.type == MessageType.call) {
                              return CallMessageBubble(
                                callType: msg.callType ?? 'audio',
                                callStatus: msg.callStatus ?? 'active',
                                durationSeconds: msg.durationSeconds,
                                time: formatCallBubbleTime(msg.createdAt),
                                isMe: isMe,
                                senderId: msg.senderId,
                                senderName: isMe ? 'You' : displayName,
                                currentUserId: _currentUser?.uid ?? '',
                                groupId: widget.groupId,
                                members: _members,
                                theme: t,
                                isFirstInGroup: isFirstInGroup,
                                isLastInGroup: isLastInGroup,
                              );
                            }

                            if (msg.type == MessageType.invite &&
                                msg.activityId != null) {
                              if (msg.activityType == 'triRace') {
                                return TriRaceInviteMessageCard(
                                  raceId: msg.activityId!,
                                  content: msg.content,
                                  isMe: isMe,
                                  senderName: isMe ? null : displayName,
                                  time: formatChatTime(msg.createdAt),
                                );
                              }
                              return InviteMessageCard(
                                sessionId: msg.activityId!,
                                content: msg.content,
                                isMe: isMe,
                                senderName: isMe ? null : displayName,
                                time: formatChatTime(msg.createdAt),
                              );
                            }

                            if (msg.type == MessageType.text) {
                              final groupLinkMatch = RegExp(
                                r'wedo://group/([^\s]+)',
                              ).firstMatch(msg.content);
                              if (groupLinkMatch != null) {
                                return GroupInviteMessageCard(
                                  groupId: groupLinkMatch.group(1)!,
                                  isMe: isMe,
                                  senderName: isMe ? null : displayName,
                                  time: formatChatTime(msg.createdAt),
                                  groupInviteData: msg.groupInviteData,
                                );
                              }
                            }

                          return MessageBubble(
                            content: msg.content,
                            isMe: isMe,
                            senderName: isMe
                                ? null
                                : (isFirstInGroup ? displayName : null),
                            time: formatChatTime(msg.createdAt),
                            theme: t,
                            isFirstInGroup: isFirstInGroup,
                            isLastInGroup: isLastInGroup,
                            createdAt: msg.createdAt,
                            edited: msg.edited,
                            onEdit: isMe ? () => _editMessage(msg) : null,
                            onDeleteForEveryone: isMe
                                ? () => _deleteMessageForEveryone(msg)
                                : null,
                            onDeleteForMe: () => _deleteMessageForMe(msg),
                            senderPhotoUrl: !isMe
                                ? (_memberPhotos[msg.senderId]?.isNotEmpty == true ? _memberPhotos[msg.senderId] : null)
                                : null,
                            senderAvatarAsset: !isMe
                                ? _memberAvatarAssets[msg.senderId]
                                : null,
                            isRead: isMe && msg.isRead,
                            currentUid: _currentUser?.uid,
                            onReply: () => _startReply(msg),
                            onReact: (emoji) => _toggleReaction(msg, emoji),
                            reactions: msg.reactions,
                            replyToContent: msg.replyToContent,
                            replyToSender: msg.replyToSender,
                          );
                        }

                        Widget wrapWithSwipe(Widget child) {
                          if (isSystem || msg.type == MessageType.call ||
                              msg.type == MessageType.event ||
                              msg.type == MessageType.poll) {
                            return child;
                          }
                          return SwipeReplyWrapper(
                            onReply: () => _startReply(msg),
                            child: child,
                          );
                        }

                        if (showDateSeparator) {
                          return Column(
                            children: [
                              DateSeparator(timestamp: msg.createdAt),
                              wrapWithSwipe(buildMessage()),
                            ],
                          );
                        }
                          return wrapWithSwipe(buildMessage());
                      },
                    );
                  },
                ),
                if (_newMessageCount > 0)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _scrollToBottom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFE4EF0),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFE4EF0,
                                ).withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_downward,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_newMessageCount New Message${_newMessageCount > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 16, 6),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(color: t.accent, width: 3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _replyingTo!.senderName.isNotEmpty
                                      ? _replyingTo!.senderName
                                      : 'You',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: t.accent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _replyingTo!.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _cancelReply,
                            child: Icon(Icons.close,
                                size: 18,
                                color:
                                    Colors.white.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: GestureDetector(
                          onTap: _showComposerMenu,
                          child: Image.asset(
                            'assets/icons/app.png',
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(
                              Icons.add_circle_outline,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: AudioRecorderButton(
                            onRecordingComplete: _onAudioRecorded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: TextField(
                              controller: _messageCtrl,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: _replyingTo != null
                                    ? 'Reply...'
                                    : 'Message',
                                hintStyle: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.5)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(35),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(35),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(35),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor:
                                    Colors.white.withValues(alpha: 0.10),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Image.asset(
                                    'assets/icons/emoji.png',
                                    width: 17,
                                    height: 17,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Icon(
                                      Icons.emoji_emotions_outlined,
                                      size: 17,
                                      color: Colors.white
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Image.asset(
                          'assets/icons/send.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: t.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  String _ownDisplayName() {
    final u = _currentUser;
    if (u == null) return 'You';
    final name = _getDisplayName(
      u.uid,
      (u.displayName ?? '').trim().isNotEmpty
          ? u.displayName!
          : (u.email ?? 'You'),
    );
    return name.isNotEmpty ? name : 'You';
  }
}

// ── Chat background dotted grid (same pattern as Home screen) ────────────────

class _ChatDottedGrid extends StatelessWidget {
  const _ChatDottedGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.infinite, painter: _ChatGridPainter());
  }
}

class _ChatGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    const spacingX = 28.0;
    const spacingY = 28.0;
    const dotRadius = 1.5;

    for (double x = spacingX / 2; x < size.width; x += spacingX) {
      for (double y = spacingY / 2; y < size.height; y += spacingY) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Animated beating-heart NEW indicator ─────────────────────────────────────

class _HeartbeatDot extends StatefulWidget {
  const _HeartbeatDot();

  @override
  State<_HeartbeatDot> createState() => _HeartbeatDotState();
}

class _HeartbeatDotState extends State<_HeartbeatDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final scale = 1.0 + (_ctrl.value * 0.25);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.9),
            ),
            child: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 13,
            ),
          ),
        );
      },
    );
  }
}
