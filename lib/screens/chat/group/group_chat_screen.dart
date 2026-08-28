import 'dart:async';
import 'dart:io';
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
import '../../../services/theme/chat_theme_resolver.dart';
import '../../../utils/time_format.dart';
import '../../../widgets/message_bubble.dart';
import '../../../widgets/date_separator.dart';
import '../../../widgets/invite_message_card.dart';
import '../../../widgets/group_invite_message_card.dart';
import '../../../widgets/composer_option.dart';
import '../../../widgets/audio_recorder_button.dart';
import '../../../widgets/chat_background_painter.dart';
import '../../../widgets/typing_indicator.dart';
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
  List<String> _members = [];
  late Stream<GroupChat?> _groupStream;
  bool _isUploading = false;
  final Map<String, ChatEvent> _events = {};
  final Map<String, ChatPoll> _polls = {};
  AppChatTheme _chatTheme = ChatThemeResolver.defaultTheme;
  int _newMessageCount = 0;
  bool _isAtBottom = true;
  List<ChatMessage> _previousMessages = [];
  StreamSubscription<List<ChatMessage>>? _messagesSub;
  late Stream<List<ChatMessage>> _messagesStream;
  final LayerLink _attachLayerLink = LayerLink();
  OverlayEntry? _attachMenuOverlay;

  @override
  void initState() {
    super.initState();
    _groupStream = _groupService.getGroupStream(widget.groupId);
    _messagesStream = _groupService.getMessagesStream(widget.groupId);
    _loadGroupInfo();
    if (_currentUser != null) {
      _groupService.markMessagesAsRead(widget.groupId, _currentUser.uid);
    }
    _messageCtrl.addListener(_onTextChanged);
    _scrollCtrl.addListener(_onScroll);
    _messagesSub = _messagesStream.listen((messages) {
      final prevLength = _previousMessages.length;
      final newMessageArrived = messages.length > prevLength;
      final wasAtBottom = _isAtBottom;

      _previousMessages = messages;

      if (!mounted) return;

      if (wasAtBottom && newMessageArrived) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
        });
      } else if (!wasAtBottom && newMessageArrived) {
        setState(() => _newMessageCount += messages.length - prevLength);
      }
    });
  }

  Future<void> _loadGroupInfo() async {
    final group = await _groupService.getGroup(widget.groupId);
    final nicknames = await _groupService.getMemberNicknames(widget.groupId);
    final theme = await ChatThemeResolver().resolve(widget.groupId, 'group_chats');
    if (group != null && mounted) {
      setState(() {
        _groupName = group.name;
        _groupPhotoUrl = group.photoUrl;
        _nicknames = nicknames;
        _members = List<String>.from(group.members);
        _chatTheme = theme;
      });
    }
  }

  Future<void> _loadMemberPhoto(String uid) async {
    if (_memberPhotos.containsKey(uid)) return;
    final user = await _groupService.getUser(uid);
    if (user != null && mounted) {
      setState(() => _memberPhotos[uid] = user.photoUrl ?? '');
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
    return _nicknames[uid] ?? fallback;
  }

  Timer? _typingTimer;

  void _onTextChanged() {
    if (_currentUser == null) return;
    final hasText = _messageCtrl.text.trim().isNotEmpty;
    _groupService.setTyping(
      groupId: widget.groupId,
      uid: _currentUser!.uid,
      isTyping: hasText,
    );
    _typingTimer?.cancel();
    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _groupService.setTyping(
          groupId: widget.groupId,
          uid: _currentUser!.uid,
          isTyping: false,
        );
      });
    }
  }

  @override
  void dispose() {
    _dismissAttachMenu();
    _typingTimer?.cancel();
    if (_currentUser != null) {
      _groupService.setTyping(
        groupId: widget.groupId,
        uid: _currentUser!.uid,
        isTyping: false,
      );
    }
    _messagesSub?.cancel();
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
      senderName: _getDisplayName(_currentUser.uid, _currentUser.displayName ?? _currentUser.email ?? 'Unknown'),
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
        content: const Text('This message will be deleted for everyone in this group.'),
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

  Future<void> _pickAndSendImage({bool camera = false}) async {
    if (_currentUser == null) return;

    if (camera) {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _isUploading = true);
      try {
        await _groupService.sendImageMessage(
          groupId: widget.groupId,
          senderId: _currentUser.uid,
          senderName: _getDisplayName(
              _currentUser.uid,
              _currentUser.displayName ??
                  _currentUser.email ??
                  'Unknown'),
          imageFile: File(picked.path),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send photo: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    } else {
      final picked = await _imagePicker.pickMultiImage(imageQuality: 80);
      if (picked.isEmpty) return;
      setState(() => _isUploading = true);
      try {
        for (final file in picked) {
          await _groupService.sendImageMessage(
            groupId: widget.groupId,
            senderId: _currentUser.uid,
            senderName: _getDisplayName(
                _currentUser.uid,
                _currentUser.displayName ??
                    _currentUser.email ??
                    'Unknown'),
            imageFile: File(file.path),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send photos: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _onAudioRecorded(File audioFile, int durationSeconds) async {
    if (_currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      await _groupService.sendAudioMessage(
        groupId: widget.groupId,
        senderId: _currentUser.uid,
        senderName: _getDisplayName(_currentUser.uid, _currentUser.displayName ?? _currentUser.email ?? 'Unknown'),
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
        builder: (_) => OutgoingCallScreen(
          call: call,
          callName: _groupName,
        ),
      ),
    );
  }

  void _showComposerMenu() {
    if (_attachMenuOverlay != null) {
      _dismissAttachMenu();
      return;
    }

    final overlay = Overlay.of(context);
    _attachMenuOverlay = OverlayEntry(
      builder: (context) => _AttachMenu(
        layerLink: _attachLayerLink,
        onDismiss: _dismissAttachMenu,
        onPhotoTap: () {
          _dismissAttachMenu();
          _pickAndSendImage(camera: false);
        },
        onCameraTap: () {
          _dismissAttachMenu();
          _pickAndSendImage(camera: true);
        },
        onEventTap: () async {
          _dismissAttachMenu();
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreateEventScreen(groupId: widget.groupId),
            ),
          );
          if (result == true) _loadGroupInfo();
        },
        onPollTap: () async {
          _dismissAttachMenu();
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePollScreen(groupId: widget.groupId),
            ),
          );
          if (result == true) _loadGroupInfo();
        },
      ),
    );
    overlay.insert(_attachMenuOverlay!);
  }

  void _dismissAttachMenu() {
    _attachMenuOverlay?.remove();
    _attachMenuOverlay = null;
  }

  void _toggleReaction(ChatMessage msg, String emoji) async {
    if (_currentUser == null) return;
    if (emoji.isEmpty) {
      await _groupService.removeReaction(
        groupId: widget.groupId,
        messageId: msg.id,
        uid: _currentUser!.uid,
      );
    } else {
      await _groupService.addReaction(
        groupId: widget.groupId,
        messageId: msg.id,
        uid: _currentUser!.uid,
        emoji: emoji,
      );
    }
  }

  ChatMessage? _replyingTo;

  void _startReply(ChatMessage msg) {
    setState(() => _replyingTo = msg);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = _chatTheme;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.appBarBackground,
        title: StreamBuilder<GroupChat?>(
          stream: _groupStream,
          builder: (context, snapshot) {
            final group = snapshot.data;
            final photoUrl = group?.photoUrl ?? _groupPhotoUrl;
            return Row(
              children: [
                CircleAvatar(
                  key: ValueKey(photoUrl),
                  radius: 14,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? const Icon(Icons.group, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group?.name ?? _groupName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            tooltip: 'Audio call',
            onPressed: () => _startCall(CallType.audio),
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Video call',
            onPressed: () => _startCall(CallType.video),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              await Navigator.pushNamed(context, '/group-info', arguments: widget.groupId);
              _loadGroupInfo();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(backgroundColor: Colors.transparent),
          Expanded(
            child: Stack(
              children: [
                Container(color: t.background),
                ChatBackground(
                  style: t.backgroundStyle,
                  color: t.accent,
                  opacity: t.backgroundOpacity,
                ),
                StreamBuilder<List<ChatMessage>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = (snapshot.data ?? [])
                          .where((m) => !m.deletedFor.contains(_currentUser?.uid))
                          .toList();
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            'No messages yet',
                            style: TextStyle(color: t.textSecondary),
                          ),
                        );
                      }

                  return ListView.builder(
                    reverse: true,
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == _currentUser?.uid;
                      final isSystem = msg.type == MessageType.system;

                      final sameSenderAsNextOlder = index + 1 < messages.length &&
                          messages[index + 1].senderId == msg.senderId &&
                          isSameDay(msg.createdAt, messages[index + 1].createdAt);
                      final sameSenderAsPrevNewer = index - 1 >= 0 &&
                          messages[index - 1].senderId == msg.senderId &&
                          isSameDay(msg.createdAt, messages[index - 1].createdAt);
                      final isFirstInGroup = !sameSenderAsNextOlder;
                      final isLastInGroup = !sameSenderAsPrevNewer;

                      final showDateSeparator = index > 0 && !isSameDay(
                            messages[index].createdAt,
                            messages[index - 1].createdAt,
                          );

                      Widget buildMessage() {
                        if (isSystem) {
                          return MessageBubble(
                            content: msg.content,
                            isMe: false,
                            senderName: msg.senderName.isNotEmpty ? msg.senderName : null,
                            time: formatChatTime(msg.createdAt),
                            isSystem: true,
                            theme: t,
                            isFirstInGroup: isFirstInGroup,
                            isLastInGroup: isLastInGroup,
                            createdAt: msg.createdAt,
                          );
                        }

                        if (msg.type == MessageType.event && msg.refId != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) => _loadEventPollData(msg));
                          final evt = _events[msg.refId];
                          return MessageBubble(
                            content: msg.content,
                            isMe: isMe,
                            senderName: isMe ? null : (isFirstInGroup ? _getDisplayName(msg.senderId, msg.senderName) : null),
                            time: formatChatTime(msg.createdAt),
                            event: evt,
                            currentUid: _currentUser?.uid,
                            theme: t,
                            isFirstInGroup: isFirstInGroup,
                            isLastInGroup: isLastInGroup,
                            createdAt: msg.createdAt,
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

                        if (msg.type == MessageType.poll && msg.refId != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) => _loadEventPollData(msg));
                          return MessageBubble(
                            content: msg.content,
                            isMe: isMe,
                            senderName: isMe ? null : (isFirstInGroup ? _getDisplayName(msg.senderId, msg.senderName) : null),
                            time: formatChatTime(msg.createdAt),
                            poll: _polls[msg.refId],
                            currentUid: _currentUser?.uid,
                            theme: t,
                            isFirstInGroup: isFirstInGroup,
                            isLastInGroup: isLastInGroup,
                            createdAt: msg.createdAt,
                          );
                        }

                        final displayName = _getDisplayName(
                          msg.senderId,
                          msg.senderName,
                        );

                        if (!isMe && !_memberPhotos.containsKey(msg.senderId)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMemberPhoto(msg.senderId));
                        }

                        if (msg.type == MessageType.invite && msg.activityId != null) {
                          return InviteMessageCard(
                            sessionId: msg.activityId!,
                            content: msg.content,
                            isMe: isMe,
                            senderName: isMe ? null : displayName,
                            time: formatChatTime(msg.createdAt),
                          );
                        }

                        if (msg.type == MessageType.image && msg.imageUrl != null) {
                          return MessageBubble(
                            content: msg.content,
                            imageUrl: msg.imageUrl,
                            isMe: isMe,
                            senderName: isMe ? null : (isFirstInGroup ? displayName : null),
                            time: formatChatTime(msg.createdAt),
                            theme: t,
                            isFirstInGroup: isFirstInGroup,
                            isLastInGroup: isLastInGroup,
                            createdAt: msg.createdAt,
                            edited: msg.edited,
                            onEdit: isMe ? () => _editMessage(msg) : null,
                            onDeleteForEveryone: isMe ? () => _deleteMessageForEveryone(msg) : null,
                            onDeleteForMe: () => _deleteMessageForMe(msg),
                            senderPhotoUrl: !isMe ? (_memberPhotos[msg.senderId] ?? '') : null,
                            isRead: isMe && msg.isRead,
                            reactions: msg.reactions,
                            currentUid: _currentUser?.uid,
                            onReact: (emoji) => _toggleReaction(msg, emoji),
                            onReply: () => _startReply(msg),
                            replyToContent: msg.replyToContent,
                            replyToSender: msg.replyToSender,
                          );
                        }

                        if (msg.type == MessageType.audio && msg.audioUrl != null) {
                          return MessageBubble(
                            content: msg.content,
                            audioUrl: msg.audioUrl,
                            durationSeconds: msg.durationSeconds,
                            isMe: isMe,
                            senderName: isMe ? null : (isFirstInGroup ? displayName : null),
                            time: formatChatTime(msg.createdAt),
                            theme: t,
                            isFirstInGroup: isFirstInGroup,
                            isLastInGroup: isLastInGroup,
                            createdAt: msg.createdAt,
                            edited: msg.edited,
                            onEdit: isMe ? () => _editMessage(msg) : null,
                            onDeleteForEveryone: isMe ? () => _deleteMessageForEveryone(msg) : null,
                            onDeleteForMe: () => _deleteMessageForMe(msg),
                            senderPhotoUrl: !isMe ? (_memberPhotos[msg.senderId] ?? '') : null,
                            isRead: isMe && msg.isRead,
                            reactions: msg.reactions,
                            currentUid: _currentUser?.uid,
                            onReact: (emoji) => _toggleReaction(msg, emoji),
                            onReply: () => _startReply(msg),
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

                        if (msg.type == MessageType.text) {
                          final groupLinkMatch = RegExp(r'wedo://group/([^\s]+)').firstMatch(msg.content);
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
                          senderName: isMe ? null : (isFirstInGroup ? displayName : null),
                          time: formatChatTime(msg.createdAt),
                          theme: t,
                          isFirstInGroup: isFirstInGroup,
                          isLastInGroup: isLastInGroup,
                          createdAt: msg.createdAt,
                          edited: msg.edited,
                          onEdit: isMe ? () => _editMessage(msg) : null,
                          onDeleteForEveryone: isMe ? () => _deleteMessageForEveryone(msg) : null,
                          onDeleteForMe: () => _deleteMessageForMe(msg),
                          senderPhotoUrl: !isMe ? (_memberPhotos[msg.senderId] ?? '') : null,
                          isRead: isMe && msg.isRead,
                          reactions: msg.reactions,
                          currentUid: _currentUser?.uid,
                          onReact: (emoji) => _toggleReaction(msg, emoji),
                          onReply: () => _startReply(msg),
                          replyToContent: msg.replyToContent,
                          replyToSender: msg.replyToSender,
                        );
                      }

                      if (showDateSeparator) {
                        return Column(
                          children: [
                            DateSeparator(timestamp: msg.createdAt),
                            buildMessage(),
                          ],
                        );
                      }
                      return buildMessage();
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFE4EF0),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
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
           Divider(height: 1, thickness: 1, color: t.divider),
           if (_replyingTo != null)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
               color: t.composerBackground,
               child: Row(
                 children: [
                   Container(
                     width: 3,
                     height: 32,
                     decoration: BoxDecoration(
                       color: t.accent,
                       borderRadius: BorderRadius.circular(2),
                     ),
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           _replyingTo!.senderName,
                           style: TextStyle(
                             fontSize: 12,
                             fontWeight: FontWeight.w600,
                             color: t.accent,
                           ),
                         ),
                         Text(
                           _replyingTo!.content,
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                           style: TextStyle(
                             fontSize: 12,
                             color: t.textSecondary,
                           ),
                         ),
                       ],
                     ),
                   ),
                   IconButton(
                     icon: Icon(Icons.close, size: 18, color: t.textSecondary),
                     onPressed: _cancelReply,
                     padding: EdgeInsets.zero,
                     constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                   ],
                 ),
               ),
             StreamBuilder<List<String>>(
              stream: _groupService.getTypingUsers(widget.groupId),
              builder: (context, snapshot) {
                final typingUids = snapshot.data ?? [];
                final otherTyping = typingUids
                    .where((uid) => uid != _currentUser?.uid)
                    .toList();
                if (otherTyping.isEmpty) return const SizedBox.shrink();
                final names = otherTyping
                    .map((uid) => _nicknames[uid] ?? 'Someone')
                    .toList();
                final label = names.length == 1
                    ? names.first
                    : '${names[0]} and ${names.length - 1} more';
                return TypingIndicator(typingUserName: label);
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              color: t.composerBackground,
            child: SafeArea(
              child: Row(
                children: [
                  CompositedTransformTarget(
                    link: _attachLayerLink,
                    child: IconButton(
                      icon: Icon(
                        _attachMenuOverlay != null
                            ? Icons.close
                            : Icons.add_circle_outline,
                        color: t.textSecondary,
                      ),
                      onPressed: _showComposerMenu,
                    ),
                  ),
                  AudioRecorderButton(onRecordingComplete: _onAudioRecorded),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(color: t.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: t.inputBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: t.accent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachMenu extends StatelessWidget {
  final LayerLink layerLink;
  final VoidCallback onDismiss;
  final VoidCallback onPhotoTap;
  final VoidCallback onCameraTap;
  final VoidCallback onEventTap;
  final VoidCallback onPollTap;

  const _AttachMenu({
    required this.layerLink,
    required this.onDismiss,
    required this.onPhotoTap,
    required this.onCameraTap,
    required this.onEventTap,
    required this.onPollTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-12, -220),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ComposerOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    color: Colors.blue,
                    onTap: onPhotoTap,
                  ),
                  ComposerOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    color: Colors.orange,
                    onTap: onCameraTap,
                  ),
                  ComposerOption(
                    icon: Icons.event_outlined,
                    label: 'Event',
                    color: Colors.teal,
                    onTap: onEventTap,
                  ),
                  ComposerOption(
                    icon: Icons.poll_outlined,
                    label: 'Poll',
                    color: Colors.deepPurple,
                    onTap: onPollTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
