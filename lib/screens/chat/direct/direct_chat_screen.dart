import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/call.dart';
import '../../../models/event.dart';
import '../../../models/chat_theme.dart';
import '../../../models/message.dart';
import '../../../models/poll.dart';
import '../../../services/direct/direct_service.dart';
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
import '../../call/outgoing_call_screen.dart';
import '../event/create_event_screen.dart';
import '../event/event_detail_screen.dart';
import '../poll/create_poll_screen.dart';
import 'direct_chat_info_screen.dart';

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUid;
  const DirectChatScreen({
    super.key,
    required this.chatId,
    required this.otherUid,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _directService = DirectService();
  final _callService = CallService();
  final _eventService = EventService();
  final _pollService = PollService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _imagePicker = ImagePicker();
  String _otherName = '';
  Map<String, String> _nicknames = {};
  bool _isUploading = false;
  final Map<String, ChatEvent> _events = {};
  final Map<String, ChatPoll> _polls = {};
  AppChatTheme _chatTheme = ChatThemeResolver.defaultTheme;
  int _newMessageCount = 0;
  bool _isAtBottom = true;
  List<ChatMessage> _previousMessages = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    if (_currentUser != null) {
      _directService.markMessagesAsRead(widget.chatId, _currentUser.uid);
    }
    _scrollCtrl.addListener(_onScroll);
  }

  Future<void> _loadData() async {
    final user = await _directService.getUser(widget.otherUid);
    final nicknames = await _directService.getNicknames(widget.chatId);
    final theme = await ChatThemeResolver().resolve(widget.chatId, 'direct_chats');
    if (mounted) {
      setState(() {
        _otherName = user?.displayName ?? widget.otherUid;
        _nicknames = nicknames;
        _chatTheme = theme;
      });
    }
  }

  String _getDisplayName() {
    if (_currentUser == null) return _otherName;
    return _nicknames[_currentUser.uid] ?? _otherName;
  }

  Future<void> _loadEventPollData(ChatMessage msg) async {
    if (msg.refId == null) return;
    if (msg.type == MessageType.event && !_events.containsKey(msg.refId)) {
      final event = await _eventService.getEvent(
        msg.refId!,
        chatId: widget.chatId,
      );
      if (event != null && mounted) {
        setState(() => _events[msg.refId!] = event);
      }
    } else if (msg.type == MessageType.poll && !_polls.containsKey(msg.refId)) {
      final poll = await _pollService.getPoll(
        msg.refId!,
        chatId: widget.chatId,
      );
      if (poll != null && mounted) {
        setState(() => _polls[msg.refId!] = poll);
      }
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final currentScroll = _scrollCtrl.offset;
    final atBottom = (maxScroll - currentScroll) < 80;
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
      if (atBottom) {
        setState(() => _newMessageCount = 0);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _newMessageCount = 0);
    }
  }

  void _onMessagesUpdated(List<ChatMessage> messages) {
    if (_previousMessages.isNotEmpty && !_isAtBottom) {
      final newCount = messages.length - _previousMessages.length;
      if (newCount > 0) {
        setState(() => _newMessageCount += newCount);
      }
    }
    _previousMessages = messages;
    if (_isAtBottom && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    }
  }

  void _sendMessage() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    _directService.sendMessage(
      chatId: widget.chatId,
      senderId: _currentUser.uid,
      senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
      text: text,
    );

    _messageCtrl.clear();
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

    final picked = await _imagePicker.pickImage(source: source, imageQuality: 80);
    if (picked == null || _currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      await _directService.sendImageMessage(
        chatId: widget.chatId,
        senderId: _currentUser.uid,
        senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
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
  }

  Future<void> _onAudioRecorded(File audioFile, int durationSeconds) async {
    if (_currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      await _directService.sendAudioMessage(
        chatId: widget.chatId,
        senderId: _currentUser.uid,
        senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
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

    final callId = await _callService.startCall(
      chatId: widget.chatId,
      createdBy: _currentUser.uid,
      type: type,
      members: [_currentUser.uid, widget.otherUid],
    );

    if (!mounted) return;

    final callStream = _callService.getCallStream(callId);
    final call = await callStream.firstWhere(
      (c) => c != null,
      orElse: () => null,
    );

    if (!mounted || call == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutgoingCallScreen(
          call: call,
          callName: _otherName,
        ),
      ),
    );
  }

  void _showAttachMenu() {
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
                'Attach',
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
                          builder: (_) => CreateEventScreen(
                            chatId: widget.chatId,
                          ),
                        ),
                      );
                      if (result == true) _loadData();
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
                          builder: (_) => CreatePollScreen(
                            chatId: widget.chatId,
                          ),
                        ),
                      );
                      if (result == true) _loadData();
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
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.appBarBackground,
        title: Text(
          _getDisplayName(),
          style: TextStyle(color: t.isDark ? Colors.white : Colors.white, fontWeight: FontWeight.w600),
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
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DirectChatInfoScreen(
                    chatId: widget.chatId,
                    otherUid: widget.otherUid,
                  ),
                ),
              );
              _loadData();
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
                Container(
                  color: t.background,
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: _directService.getMessagesStream(widget.chatId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data ?? [];
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            'No messages yet',
                            style: TextStyle(color: t.textSecondary),
                          ),
                        );
                      }

                      _onMessagesUpdated(messages);

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == _currentUser?.uid;
                      final isSystem = msg.type == MessageType.system;

                      final showDateSeparator = index == 0 ||
                          !isSameDay(
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
                          );
                        }

                        if (msg.type == MessageType.event && msg.refId != null) {
                          _loadEventPollData(msg);
                          final evt = _events[msg.refId];
                          return MessageBubble(
                            content: msg.content,
                            isMe: isMe,
                            senderName: msg.senderName.isNotEmpty ? msg.senderName : null,
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
                                          chatId: widget.chatId,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          );
                        }

                        if (msg.type == MessageType.poll && msg.refId != null) {
                          _loadEventPollData(msg);
                          return MessageBubble(
                            content: msg.content,
                            isMe: isMe,
                            senderName: null,
                            time: formatChatTime(msg.createdAt),
                            poll: _polls[msg.refId],
                            currentUid: _currentUser?.uid,
                            theme: t,
                          );
                        }

                        if (msg.type == MessageType.invite && msg.activityId != null) {
                          return InviteMessageCard(
                            sessionId: msg.activityId!,
                            content: msg.content,
                            isMe: isMe,
                            senderName: null,
                            time: formatChatTime(msg.createdAt),
                          );
                        }

                        if (msg.type == MessageType.image && msg.imageUrl != null) {
                          return MessageBubble(
                            content: msg.content,
                            imageUrl: msg.imageUrl,
                            isMe: isMe,
                            senderName: null,
                            time: formatChatTime(msg.createdAt),
                            theme: t,
                          );
                        }

                        if (msg.type == MessageType.audio && msg.audioUrl != null) {
                          return MessageBubble(
                            content: msg.content,
                            audioUrl: msg.audioUrl,
                            durationSeconds: msg.durationSeconds,
                            isMe: isMe,
                            senderName: null,
                            time: formatChatTime(msg.createdAt),
                            theme: t,
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
                            senderName: _otherName,
                            currentUserId: _currentUser!.uid,
                            chatId: widget.chatId,
                            members: [_currentUser.uid, widget.otherUid],
                          );
                        }

                        if (msg.type == MessageType.text) {
                          final groupLinkMatch = RegExp(r'wedo://group/([^\s]+)').firstMatch(msg.content);
                          if (groupLinkMatch != null) {
                            return GroupInviteMessageCard(
                              groupId: groupLinkMatch.group(1)!,
                              isMe: isMe,
                              senderName: null,
                              time: formatChatTime(msg.createdAt),
                              groupInviteData: msg.groupInviteData,
                            );
                          }
                        }

                        return MessageBubble(
                          content: msg.content,
                          isMe: isMe,
                          senderName: null,
                          time: formatChatTime(msg.createdAt),
                          theme: t,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            color: t.composerBackground,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: t.textSecondary,
                    ),
                    onPressed: _showAttachMenu,
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
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
