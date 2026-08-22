import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/call.dart';
import '../../../models/event.dart';
import '../../../models/message.dart';
import '../../../models/poll.dart';
import '../../../models/user_entity.dart';
import '../../../services/direct/direct_service.dart';
import '../../../services/event/event_service.dart';
import '../../../services/poll/poll_service.dart';
import '../../../services/call/call_service.dart';
import '../../../utils/time_format.dart';
import '../../../widgets/message_bubble.dart';
import '../../../widgets/invite_message_card.dart';
import '../../../widgets/composer_option.dart';
import '../../../widgets/audio_recorder_button.dart';
import '../../call/outgoing_call_screen.dart';
import '../image_viewer_screen.dart';
import '../event/create_event_screen.dart';
import '../event/event_detail_screen.dart';
import '../poll/create_poll_screen.dart';
import '../search/direct_chat_search_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
    if (_currentUser != null) {
      _directService.markMessagesAsRead(widget.chatId, _currentUser.uid);
    }
  }

  Future<void> _loadData() async {
    final user = await _directService.getUser(widget.otherUid);
    final nicknames = await _directService.getNicknames(widget.chatId);
    if (mounted) {
      setState(() {
        _otherName = user?.displayName ?? widget.otherUid;
        _nicknames = nicknames;
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
    final call = await callStream.firstWhere((c) => c != null);

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_getDisplayName()),
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
            icon: const Icon(Icons.search),
            onPressed: () async {
              final messageId = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => DirectChatSearchScreen(chatId: widget.chatId),
                ),
              );
              if (messageId != null && _scrollCtrl.hasClients) {
                final messages = await _directService.getMessagesOnce(
                  widget.chatId,
                );
                final index = messages.indexWhere((m) => m.id == messageId);
                if (index != -1 && _scrollCtrl.hasClients) {
                  _scrollCtrl.animateTo(
                    index * 80.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _DirectChatInfoScreen(
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
            child: StreamBuilder<List<ChatMessage>>(
              stream: _directService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _currentUser?.uid;
                    final isSystem = msg.type == MessageType.system;

                    if (isSystem) {
                      return MessageBubble(
                        content: msg.content,
                        isMe: false,
                        senderName: msg.senderName.isNotEmpty ? msg.senderName : null,
                        time: formatChatTime(msg.createdAt),
                        isSystem: true,
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
                      );
                    }

                    if (msg.type == MessageType.call) {
                      return CallMessageBubble(
                        callType: msg.callType ?? 'audio',
                        callStatus: msg.callStatus ?? 'active',
                        durationSeconds: msg.durationSeconds,
                        time: formatChatTime(msg.createdAt),
                        isMe: isMe,
                        senderId: msg.senderId,
                        senderName: _otherName,
                        currentUserId: _currentUser!.uid,
                        chatId: widget.chatId,
                        members: [_currentUser.uid, widget.otherUid],
                      );
                    }

                    return MessageBubble(
                      content: msg.content,
                      isMe: isMe,
                      senderName: null,
                      time: formatChatTime(msg.createdAt),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.grey,
                    ),
                    onPressed: _showAttachMenu,
                  ),
                  AudioRecorderButton(onRecordingComplete: _onAudioRecorded),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
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

class _DirectChatInfoScreen extends StatefulWidget {
  final String chatId;
  final String otherUid;
  const _DirectChatInfoScreen({required this.chatId, required this.otherUid});

  @override
  State<_DirectChatInfoScreen> createState() => _DirectChatInfoScreenState();
}

class _DirectChatInfoScreenState extends State<_DirectChatInfoScreen> {
  final _directService = DirectService();
  UserEntity? _otherUser;
  Map<String, String> _nicknames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _directService.getUser(widget.otherUid);
    final nicks = await _directService.getNicknames(widget.chatId);
    if (mounted) {
      setState(() {
        _otherUser = user;
        _nicknames = nicks;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeNickname() async {
    final currentUid = _directService.getCurrentUid();
    final currentNickname = currentUid != null
        ? _nicknames[currentUid] ?? ''
        : '';
    final ctrl = TextEditingController(text: currentNickname);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Nickname'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nickname for yourself',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && currentUid != null && mounted) {
      await _directService.updateNickname(
        chatId: widget.chatId,
        uid: currentUid,
        nickname: result,
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _otherUser?.displayName ?? widget.otherUid;
    final currentUid = _directService.getCurrentUid();
    final myNickname = currentUid != null ? _nicknames[currentUid] : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Info')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_otherUser?.email != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _otherUser!.email!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: Colors.blue),
                  title: const Text('Your Nickname'),
                  subtitle: Text(myNickname ?? 'Tap to set'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changeNickname,
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Media',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _MediaSection(chatId: widget.chatId),
              ],
            ),
    );
  }
}

class _MediaSection extends StatefulWidget {
  final String chatId;
  const _MediaSection({required this.chatId});

  @override
  State<_MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends State<_MediaSection> {
  final _directService = DirectService();
  List<String> _imageUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final messages = await _directService.getMessagesOnce(widget.chatId);
    final images = messages
        .where((m) => m.type == MessageType.image && m.imageUrl != null)
        .map((m) => m.imageUrl!)
        .toList();
    if (mounted) {
      setState(() {
        _imageUrls = images;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_imageUrls.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No media shared yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImageViewerScreen(
                  imageUrl: _imageUrls[index],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }
}
