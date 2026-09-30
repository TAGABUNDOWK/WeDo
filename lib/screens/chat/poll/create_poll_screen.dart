import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/poll.dart';
import '../../../services/poll/poll_service.dart';
import '../../../services/group/group_service.dart';
import '../../../services/direct/direct_service.dart';
import '../../../services/auth/user_service.dart';
import '../../../services/notification/notification_service.dart';
import '../../../widgets/chat_default_background.dart';

const _fontFamily = 'Poppins';

class CreatePollScreen extends StatefulWidget {
  final String? groupId;
  final String? chatId;

  const CreatePollScreen({
    super.key,
    this.groupId,
    this.chatId,
  });

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _questionCtrl = TextEditingController();
  final _optionCtrls = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  final _pollService = PollService();
  final _groupService = GroupService();
  final _directService = DirectService();
  final _userService = UserService();
  final _notificationService = NotificationService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  PollType _pollType = PollType.public;
  DateTime? _closesAt;
  String _selectedDurationPreset = 'No Limit';
  bool _isCreating = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final ctrl in _optionCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length >= 6) return;
    setState(() {
      _optionCtrls.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= 2) return;
    setState(() {
      _optionCtrls[index].dispose();
      _optionCtrls.removeAt(index);
    });
  }

  Future<void> _pickCloseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _closesAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFE4EF0),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1035),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1035)),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _closesAt ?? now.add(const Duration(days: 7)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFE4EF0),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1035),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1035)),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      _closesAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _selectedDurationPreset = 'Custom';
    });
  }

  void _applyDurationPreset(String preset) {
    setState(() {
      _selectedDurationPreset = preset;
      switch (preset) {
        case '1 Hour':
          _closesAt = DateTime.now().add(const Duration(hours: 1));
          break;
        case '24 Hours':
          _closesAt = DateTime.now().add(const Duration(hours: 24));
          break;
        case '3 Days':
          _closesAt = DateTime.now().add(const Duration(days: 3));
          break;
        case '1 Week':
          _closesAt = DateTime.now().add(const Duration(days: 7));
          break;
        case 'Custom':
          _pickCloseDate();
          break;
        case 'No Limit':
        default:
          _closesAt = null;
          break;
      }
    });
  }

  Future<void> _createPoll() async {
    final question = _questionCtrl.text.trim();
    final options = _optionCtrls
        .map((ctrl) => ctrl.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2 || _currentUser == null) return;

    final uniqueOptions = options.toSet();
    if (uniqueOptions.length != options.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Poll options must be unique',
              style: TextStyle(fontFamily: _fontFamily, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1E1035),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isCreating = true);

    try {
      final userDoc = await _userService.getUserDocument(_currentUser.uid);
      final senderName = _pollType == PollType.secret
          ? 'Anonymous'
          : (userDoc?.displayName ?? 'Unknown');

      final pollId = await _pollService.createPoll(
        createdBy: _currentUser.uid,
        type: _pollType,
        question: question,
        options: options,
        closesAt: _closesAt,
        chatId: widget.chatId,
        groupId: widget.groupId,
      );

      if (widget.groupId != null) {
        await _groupService.sendPollMessage(
          groupId: widget.groupId!,
          senderId: _currentUser.uid,
          senderName: senderName,
          pollId: pollId,
          question: question,
        );
        await _groupService.sendSystemMessage(
          groupId: widget.groupId!,
          content: 'created a poll',
          senderName: senderName,
        );
        await _sendPollNotifications(
          pollId: pollId,
          question: question,
          groupId: widget.groupId!,
        );
      } else if (widget.chatId != null) {
        await _directService.sendPollMessage(
          chatId: widget.chatId!,
          senderId: _currentUser.uid,
          senderName: senderName,
          pollId: pollId,
          question: question,
        );
        await _directService.sendSystemMessage(
          chatId: widget.chatId!,
          content: 'created a poll',
          senderName: senderName,
        );
        await _sendPollNotifications(
          pollId: pollId,
          question: question,
          chatId: widget.chatId!,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create poll: $e',
              style: const TextStyle(fontFamily: _fontFamily, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1E1035),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.redAccent),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _sendPollNotifications({
    required String pollId,
    required String question,
    String? groupId,
    String? chatId,
  }) async {
    try {
      final user = _currentUser;
      if (user == null) return;
      final senderName = _pollType == PollType.secret
          ? 'Anonymous'
          : (user.displayName ?? user.email ?? 'Unknown');

      if (groupId != null) {
        final members = await _groupService.getGroupMembersWithNames(groupId);
        for (final member in members) {
          final uid = member['uid'] as String;
          if (uid == user.uid) continue;
          await _notificationService.createPollCreatedNotification(
            recipientId: uid,
            senderId: user.uid,
            senderName: senderName,
            pollId: pollId,
            question: question,
            groupId: groupId,
          );
        }
      } else if (chatId != null) {
        final chat = await _directService.getChat(chatId);
        if (chat == null) return;
        final otherUid = chat.otherUserId(user.uid);
        if (otherUid.isEmpty) return;
        await _notificationService.createPollCreatedNotification(
          recipientId: otherUid,
          senderId: user.uid,
          senderName: senderName,
          pollId: pollId,
          question: question,
          chatId: chatId,
          otherUid: user.uid,
        );
      }
    } catch (_) {}
  }

  String _formatCloseDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final formattedDate =
        '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:${dt.minute.toString().padLeft(2, '0')} $period';

    if (diff.isNegative) return 'Expired ($formattedDate)';
    if (diff.inHours < 1) return 'In ${diff.inMinutes}m ($formattedDate)';
    if (diff.inDays < 1) return 'In ${diff.inHours}h ($formattedDate)';
    return 'In ${diff.inDays}d ($formattedDate)';
  }

  @override
  Widget build(BuildContext context) {
    final validOptions = _optionCtrls.where((c) => c.text.trim().isNotEmpty).length;
    final canCreate = _questionCtrl.text.trim().isNotEmpty && validOptions >= 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Poll',
          style: TextStyle(
            color: Colors.white,
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: (_isCreating || !canCreate) ? null : _createPoll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: canCreate && !_isCreating
                        ? const LinearGradient(colors: [Color(0xFF800DD8), Color(0xFFFE4EF0)])
                        : null,
                    color: canCreate && !_isCreating ? null : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: canCreate && !_isCreating
                          ? const Color(0xFFFE4EF0).withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'POST',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: canCreate ? Colors.white : Colors.white38,
                            fontFamily: _fontFamily,
                            letterSpacing: 0.6,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ChatDefaultBackground()),
          SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuestionCard(),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    icon: Icons.tune_rounded,
                    title: 'POLL TYPE',
                    subtitle: 'Control voter anonymity',
                  ),
                  const SizedBox(height: 10),
                  _buildPollTypeToggle(),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    icon: Icons.format_list_bulleted_rounded,
                    title: 'POLL OPTIONS',
                    badge: '${_optionCtrls.length} of 6',
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(_optionCtrls.length, (index) {
                    return _buildOptionField(index);
                  }),
                  if (_optionCtrls.length < 6) ...[
                    const SizedBox(height: 6),
                    _buildAddOptionButton(),
                  ],
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    icon: Icons.schedule_rounded,
                    title: 'DURATION',
                    subtitle: 'Auto-close voting deadline',
                  ),
                  const SizedBox(height: 10),
                  _buildDurationCard(),
                  const SizedBox(height: 32),
                  _buildCreateButton(canCreate),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFE4EF0), size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Text(
                '• $subtitle',
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: _fontFamily,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: _fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionCard() {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFFFE4EF0).withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: Color(0xFFFE4EF0),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Question',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: _fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (_questionCtrl.text.isNotEmpty)
                Text(
                  '${_questionCtrl.text.length} chars',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontFamily: _fontFamily,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _questionCtrl,
            maxLines: 4,
            minLines: 2,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: _fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'What would you like to ask the group?',
              hintStyle: const TextStyle(
                color: Colors.white38,
                fontFamily: _fontFamily,
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollTypeToggle() {
    return Row(
      children: [
        Expanded(
          child: _PollTypeOption(
            title: 'Public',
            subtitle: 'Names visible',
            icon: Icons.public_rounded,
            accentColor: const Color(0xFF00E5FF),
            isSelected: _pollType == PollType.public,
            onTap: () => setState(() => _pollType = PollType.public),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PollTypeOption(
            title: 'Secret',
            subtitle: '100% anonymous',
            icon: Icons.lock_outline_rounded,
            accentColor: const Color(0xFFFE4EF0),
            isSelected: _pollType == PollType.secret,
            onTap: () => setState(() => _pollType = PollType.secret),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFFFE4EF0),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: _fontFamily,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _optionCtrls[index],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: _fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Option ${index + 1}...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontFamily: _fontFamily,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_optionCtrls.length > 2)
                  GestureDetector(
                    onTap: () => _removeOption(index),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddOptionButton() {
    return GestureDetector(
      onTap: _addOption,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFE4EF0).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Color(0xFFFE4EF0), size: 18),
            SizedBox(width: 8),
            Text(
              'Add Option',
              style: TextStyle(
                color: Color(0xFFFE4EF0),
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard() {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      color: Color(0xFF00E5FF),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _closesAt != null
                        ? _formatCloseDate(_closesAt!)
                        : 'No closing deadline',
                    style: TextStyle(
                      color: _closesAt != null ? Colors.white : Colors.white60,
                      fontFamily: _fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (_closesAt != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _closesAt = null;
                    _selectedDurationPreset = 'No Limit';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.white60,
                            fontFamily: _fontFamily,
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.close_rounded, size: 12, color: Colors.white60),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PresetChip(
                label: 'No Limit',
                isSelected: _selectedDurationPreset == 'No Limit' && _closesAt == null,
                onTap: () => _applyDurationPreset('No Limit'),
              ),
              _PresetChip(
                label: '1 Hour',
                isSelected: _selectedDurationPreset == '1 Hour',
                onTap: () => _applyDurationPreset('1 Hour'),
              ),
              _PresetChip(
                label: '24 Hours',
                isSelected: _selectedDurationPreset == '24 Hours',
                onTap: () => _applyDurationPreset('24 Hours'),
              ),
              _PresetChip(
                label: '3 Days',
                isSelected: _selectedDurationPreset == '3 Days',
                onTap: () => _applyDurationPreset('3 Days'),
              ),
              _PresetChip(
                label: '1 Week',
                isSelected: _selectedDurationPreset == '1 Week',
                onTap: () => _applyDurationPreset('1 Week'),
              ),
              _PresetChip(
                label: 'Custom 📅',
                isSelected: _selectedDurationPreset == 'Custom',
                onTap: () => _applyDurationPreset('Custom'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(bool canCreate) {
    return Column(
      children: [
        GestureDetector(
          onTap: (_isCreating || !canCreate) ? null : _createPoll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: canCreate && !_isCreating
                  ? const LinearGradient(
                      colors: [Color(0xFF800DD8), Color(0xFFFE4EF0)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: canCreate && !_isCreating
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFE4EF0).withValues(alpha: 0.35),
                        offset: const Offset(0, 4),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
              border: Border.all(
                color: canCreate && !_isCreating
                    ? const Color(0xFFFE4EF0).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isCreating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  Icon(
                    Icons.poll_rounded,
                    color: canCreate ? Colors.white : Colors.white38,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Create Poll',
                    style: TextStyle(
                      color: canCreate ? Colors.white : Colors.white38,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!canCreate) ...[
          const SizedBox(height: 8),
          Text(
            _questionCtrl.text.trim().isEmpty
                ? 'Enter a question to continue'
                : 'Add at least 2 non-empty options',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white38,
              fontFamily: _fontFamily,
            ),
          ),
        ],
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PollTypeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _PollTypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.2),
                  ),
                  child: Icon(icon, color: accentColor, size: 16),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? accentColor : Colors.white24,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: _fontFamily,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : Colors.white38,
                fontFamily: _fontFamily,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFE4EF0).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFE4EF0).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFFFE4EF0) : Colors.white70,
            fontFamily: _fontFamily,
          ),
        ),
      ),
    );
  }
}
