import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/call.dart';
import '../../../models/event.dart';
import '../../../models/chat_theme.dart';
import '../../../models/message.dart';
import '../../../models/poll.dart';
import '../../../models/user_entity.dart';
import '../../../services/direct/direct_service.dart';
import '../../../services/location/live_location_service.dart';
import '../../../services/event/event_service.dart';
import '../../../services/poll/poll_service.dart';
import '../../../services/call/call_service.dart';
import '../../../services/call/call_manager.dart';
import '../../../services/theme/chat_theme_resolver.dart';
import '../../../utils/time_format.dart';
import '../../../widgets/message_bubble.dart';
import '../../../widgets/call_button.dart';
import '../../../widgets/date_separator.dart';
import '../../../widgets/invite_message_card.dart';
import '../../../widgets/tri_race_invite_message_card.dart';
import '../../../widgets/group_invite_message_card.dart';
import '../../../widgets/location_message_card.dart';
import '../../../widgets/place_compare_sheet.dart';
import '../../../widgets/composer_option.dart';
import '../../../widgets/audio_recorder_button.dart';
import '../../../widgets/swipe_reply_wrapper.dart';
import '../../call/outgoing_call_screen.dart';
import '../../location/location_picker_screen.dart';
import '../event/create_event_screen.dart';
import '../event/event_detail_screen.dart';
import '../event/event_calendar_screen.dart';
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
  String? _otherPhotoUrl;
  String? _otherAvatarAsset;
  Map<String, String> _nicknames = {};
  bool _isUploading = false;
  final Map<String, ChatEvent> _events = {};
  final Map<String, ChatPoll> _polls = {};
  AppChatTheme _chatTheme = ChatThemeResolver.defaultTheme;
  int _newMessageCount = 0;
  bool _isAtBottom = true;
  int _lastMessageCount = 0;
  late Stream<List<ChatMessage>> _messagesStream;
  late Stream<UserEntity?> _otherUserStream;
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _messagesStream = _directService.getMessagesStream(widget.chatId);
    _otherUserStream = _directService.getUserStream(widget.otherUid);
    _otherUserStream.listen((user) {
      if (!mounted) return;
      setState(() {
        _otherName = user?.displayName ?? widget.otherUid;
        _otherPhotoUrl = user?.photoUrl;
        _otherAvatarAsset = user?.avatarAsset;
      });
    });
    _loadData();
    if (_currentUser != null) {
      _directService.markMessagesAsRead(widget.chatId, _currentUser.uid);
    }
    _scrollCtrl.addListener(_onScroll);
  }

  Future<void> _loadData() async {
    final nicknames = await _directService.getNicknames(widget.chatId);
    final theme = await ChatThemeResolver().resolve(
      widget.chatId,
      'direct_chats',
    );
    if (mounted) {
      setState(() {
        _nicknames = nicknames;
        _chatTheme = theme;
      });
    }
  }

  String _getDisplayName() {
    if (_currentUser == null) return _otherName;
    return _nicknames[widget.otherUid] ?? _otherName;
  }

  final Set<String> _refLoadAttempts = {};

  Future<void> _loadEventPollData(ChatMessage msg) async {
    if (msg.refId == null) return;
    if (msg.type == MessageType.event) {
      if (_events.containsKey(msg.refId) ||
          !_refLoadAttempts.add('event:${msg.refId}')) {
        return;
      }
      final event = await _eventService.getEvent(
        msg.refId!,
        chatId: widget.chatId,
      );
      if (event != null && mounted) {
        setState(() => _events[msg.refId!] = event);
      }
    } else if (msg.type == MessageType.poll) {
      if (_polls.containsKey(msg.refId) ||
          !_refLoadAttempts.add('poll:${msg.refId}')) {
        return;
      }
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
    _liveLocation.stop();
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

    _directService.sendMessage(
      chatId: widget.chatId,
      senderId: _currentUser.uid,
      senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
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
                _directService.editMessage(
                  chatId: widget.chatId,
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
          'This message will be deleted for everyone in this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _directService.deleteMessage(
                chatId: widget.chatId,
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
    _directService.deleteMessage(
      chatId: widget.chatId,
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
    if (_currentUser == null) return;
    if (emoji.isEmpty) {
      _directService.removeReaction(
        chatId: widget.chatId,
        messageId: msg.id,
        uid: _currentUser.uid,
      );
    } else {
      _directService.addReaction(
        chatId: widget.chatId,
        messageId: msg.id,
        uid: _currentUser.uid,
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
      await _directService.sendImageMessage(
        chatId: widget.chatId,
        senderId: _currentUser.uid,
        senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
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

  final _liveLocation = LiveLocationService();

  Future<void> _shareLocation() async {
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (picked == null || !mounted || _currentUser == null) return;

    try {
      final liveUntil = picked.liveDuration == null
          ? null
          : DateTime.now().add(picked.liveDuration!);
      final messageId = await _directService.sendLocationMessage(
        chatId: widget.chatId,
        senderId: _currentUser.uid,
        senderName:
            _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
        latitude: picked.latitude,
        longitude: picked.longitude,
        address: picked.address,
        liveUntil: liveUntil,
      );

      if (liveUntil != null && mounted) {
        _liveLocation.start(
          duration: picked.liveDuration!,
          onPosition: (lat, lng) =>
              _directService.updateLocationMessageCoords(
            chatId: widget.chatId,
            messageId: messageId,
            latitude: lat,
            longitude: lng,
          ),
          onExpired: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Live location sharing ended'),
                ),
              );
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send location: $e')));
      }
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

  Future<void> _openChatInfo() async {
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
  }

  Future<void> _startCall(CallType type) async {
    if (_currentUser == null) return;

    // An active call in this chat may already exist (started from the
    // banner, a notification or a double tap). Starting a second one gives
    // two parallel call docs that ring the peer twice and leave one of them
    // impossible to end cleanly - refuse instead.
    final existing =
        await _callService.findActiveDirectCall(widget.chatId, _currentUser.uid);
    if (existing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There\u2019s already a call running in this chat'),
        ),
      );
      return;
    }

    final callId = await _callService.startCall(
      chatId: widget.chatId,
      createdBy: _currentUser.uid,
      type: type,
      members: [_currentUser.uid, widget.otherUid],
    );

    if (!mounted) return;

    final callStream = _callService.getCallStream(callId);
    final call = await callStream.first;

    if (!mounted || call == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutgoingCallScreen(call: call, callName: _otherName),
      ),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xE6190831),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Attach',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ComposerOption(
                              icon: Icons.photo_outlined,
                              label: 'Photo',
                              color: Colors.lightBlueAccent,
                              onTap: () {
                                Navigator.pop(context);
                                _pickAndSendImage();
                              },
                            ),
                            ComposerOption(
                              icon: Icons.event_outlined,
                              label: 'Event',
                              color: Colors.tealAccent,
                              onTap: () async {
                                Navigator.pop(context);
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CreateEventScreen(chatId: widget.chatId),
                                  ),
                                );
                                if (result == true) _loadData();
                              },
                            ),
                            ComposerOption(
                              icon: Icons.poll_outlined,
                              label: 'Poll',
                              color: Colors.purpleAccent,
                              onTap: () async {
                                Navigator.pop(context);
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CreatePollScreen(chatId: widget.chatId),
                                  ),
                                );
                                if (result == true) _loadData();
                              },
                            ),
                            ComposerOption(
                              icon: Icons.location_on_outlined,
                              label: 'Location',
                              color: Colors.greenAccent,
                              onTap: () {
                                Navigator.pop(context);
                                _shareLocation();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                        child: SizedBox(
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              GestureDetector(
                                onTap: _openChatInfo,
                                behavior: HitTestBehavior.opaque,
                                child: Tooltip(
                                  message: 'Chat info',
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 80),
                                    child: StreamBuilder<UserEntity?>(
                                  stream: _otherUserStream,
                                  builder: (context, snapshot) {
                                    final user = snapshot.data;
                                    final name =
                                        _nicknames[widget.otherUid] ??
                                            user?.displayName ??
                                            widget.otherUid;
                                    final photoUrl = user?.photoUrl;
                                    final avatarAsset = user?.avatarAsset;
                                    final hasAvatarAsset = avatarAsset != null &&
                                        avatarAsset.isNotEmpty;
                                    final hasPhotoUrl = photoUrl != null &&
                                        photoUrl.isNotEmpty;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.2),
                                          backgroundImage: hasAvatarAsset
                                              ? AssetImage(avatarAsset)
                                              : hasPhotoUrl
                                                  ? NetworkImage(photoUrl)
                                                  : null,
                                          child: !hasAvatarAsset && !hasPhotoUrl
                                              ? const Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 18,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            name,
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
                                chatId: widget.chatId,
                                isGroup: false,
                                onStartAudioCall: () => _startCall(CallType.audio),
                                onStartVideoCall: () => _startCall(CallType.video),
                                onReturnToCall: CallManager().returnToCall,
                              ),
                            ],
                          ),
                        ),
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
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EventCalendarScreen(
                                      chatId: widget.chatId,
                                    ),
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/icons/calendar1.png',
                                  width: 26,
                                  height: 26,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(
                                    Icons.calendar_month,
                                    color: Colors.white,
                                    size: 26,
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
                        ],
                      ),
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

                      for (final m in messages) {
                        if ((m.type == MessageType.event ||
                                m.type == MessageType.poll) &&
                            m.refId != null) {
                          _loadEventPollData(m);
                        }
                      }

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
                                senderName: msg.senderName.isNotEmpty
                                    ? msg.senderName
                                    : null,
                                time: formatChatTime(msg.createdAt),
                                event: evt,
                                currentUid: _currentUser?.uid,
                                theme: t,
                                onEventTap: evt != null
                                    ? () {
                                        if (evt.isPlaceEvent) {
                                          showPlaceCompareSheet(context, evt);
                                          return;
                                        }
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

                      if (msg.type == MessageType.event && msg.refId != null) {
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

                          if (msg.type == MessageType.location &&
                              msg.latitude != null &&
                              msg.longitude != null) {
                            return LocationMessageCard(
                              latitude: msg.latitude!,
                              longitude: msg.longitude!,
                              isMe: isMe,
                              senderName: isMe || msg.senderName.isEmpty
                                  ? null
                                  : msg.senderName,
                              address: msg.address,
                              liveUntil: msg.liveUntil,
                              chatId: widget.chatId,
                              messageId: msg.id,
                            );
                          }

                          if (msg.type == MessageType.invite &&
                              msg.activityId != null) {
                            if (msg.activityType == 'triRace') {
                            return TriRaceInviteMessageCard(
                              raceId: msg.activityId!,
                              content: msg.content,
                              isMe: isMe,
                              senderName: null,
                              time: formatChatTime(msg.createdAt),
                            );
                          }
                          return InviteMessageCard(
                              sessionId: msg.activityId!,
                              content: msg.content,
                              isMe: isMe,
                              senderName: null,
                              time: formatChatTime(msg.createdAt),
                            );
                          }

                          if (msg.type == MessageType.image &&
                              msg.imageUrl != null) {
                            return MessageBubble(
                              content: msg.content,
                              imageUrl: msg.imageUrl,
                              isMe: isMe,
                              senderName: isMe ? _ownDisplayName() : _getDisplayName(),
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
                              senderPhotoUrl: !isMe ? _otherPhotoUrl : null,
                              senderAvatarAsset: !isMe ? _otherAvatarAsset : null,
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
                              senderName: isMe ? _ownDisplayName() : _getDisplayName(),
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
                              senderPhotoUrl: !isMe ? _otherPhotoUrl : null,
                              senderAvatarAsset: !isMe ? _otherAvatarAsset : null,
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
                              senderName: _otherName,
                              currentUserId: _currentUser?.uid ?? '',
                              chatId: widget.chatId,
                              members: [
                                _currentUser?.uid ?? '',
                                widget.otherUid,
                              ],
                              theme: t,
                              isFirstInGroup: isFirstInGroup,
                              isLastInGroup: isLastInGroup,
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
                                senderName: null,
                                time: formatChatTime(msg.createdAt),
                                groupInviteData: msg.groupInviteData,
                              );
                            }
                          }

                          return MessageBubble(
                            content: msg.content,
                            isMe: isMe,
                            senderName: isMe ? _ownDisplayName() : _getDisplayName(),
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
                            senderPhotoUrl: !isMe ? _otherPhotoUrl : null,
                            senderAvatarAsset: !isMe ? _otherAvatarAsset : null,
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

                        final item = wrapWithSwipe(buildMessage());
                        if (showDateSeparator) {
                          return Column(
                            key: ValueKey(msg.id),
                            children: [
                              DateSeparator(timestamp: msg.createdAt),
                              item,
                            ],
                          );
                        }
                        return KeyedSubtree(key: ValueKey(msg.id), child: item);
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
                          onTap: _showAttachMenu,
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
    final name = (u.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (u.email ?? '').trim();
    if (email.isNotEmpty) return email;
    return 'You';
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
