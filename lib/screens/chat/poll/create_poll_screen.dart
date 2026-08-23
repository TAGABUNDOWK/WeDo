import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/constants.dart';
import '../../../models/poll.dart';
import '../../../services/poll/poll_service.dart';
import '../../../services/group/group_service.dart';
import '../../../services/direct/direct_service.dart';
import '../../../services/auth/user_service.dart';

const _fontFamily = 'PlusJakartaSans';

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
  final _currentUser = FirebaseAuth.instance.currentUser;
  PollType _pollType = PollType.public;
  DateTime? _closesAt;
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
    final date = await showDatePicker(
      context: context,
      initialDate: _closesAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.lavenderAccent,
              onPrimary: AppColors.midnightBg,
              surface: Color(0xFF211635),
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF211635)),
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
        _closesAt ?? DateTime.now().add(const Duration(days: 7)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.lavenderAccent,
              onPrimary: AppColors.midnightBg,
              surface: Color(0xFF211635),
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF211635)),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      _closesAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _createPoll() async {
    final question = _questionCtrl.text.trim();
    final options = _optionCtrls
        .map((ctrl) => ctrl.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2 || _currentUser == null) return;

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
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create poll: $e'),
            backgroundColor: const Color(0xFF211635),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.glassBorder),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  String _formatCloseDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Poll',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createPoll,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.lavenderAccent,
                    ),
                  )
                : const Text(
                    'CREATE',
                    style: TextStyle(
                      color: AppColors.lavenderAccent,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlassCard(
              child: TextField(
                controller: _questionCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: _fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What would you like to ask?',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    fontFamily: _fontFamily,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Poll Type',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            _buildPollTypeToggle(),
            const SizedBox(height: 8),
            Text(
              _pollType == PollType.public
                  ? "Voters' choices are visible to everyone"
                  : 'All votes are anonymous',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontFamily: _fontFamily,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Options',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_optionCtrls.length, (index) {
              return _buildOptionField(index);
            }),
            if (_optionCtrls.length < 6) ...[
              const SizedBox(height: 8),
              _buildAddOptionButton(),
            ],
            const SizedBox(height: 24),
            _GlassCard(
              child: InkWell(
                onTap: _pickCloseDate,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.lavenderAccent, size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Close Date (optional)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: _fontFamily,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _closesAt != null ? _formatCloseDate(_closesAt!) : 'No closing time set',
                              style: TextStyle(
                                color: _closesAt != null
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondary.withValues(alpha: 0.5),
                                fontFamily: _fontFamily,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_closesAt != null)
                        GestureDetector(
                          onTap: () => setState(() => _closesAt = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildCreateButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPollTypeToggle() {
    return _GlassCard(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _PollTypeOption(
              label: 'Public',
              icon: Icons.public_outlined,
              isSelected: _pollType == PollType.public,
              onTap: () => setState(() => _pollType = PollType.public),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _PollTypeOption(
              label: 'Secret',
              icon: Icons.lock_outline,
              isSelected: _pollType == PollType.secret,
              onTap: () => setState(() => _pollType = PollType.secret),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.drag_handle,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _optionCtrls[index],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: _fontFamily,
                  fontSize: 14,
                ),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Option ${index + 1}',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
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
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOptionButton() {
    return GestureDetector(
      onTap: _addOption,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.lavenderAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.lavenderAccent.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.lavenderAccent, size: 18),
            SizedBox(width: 8),
            Text(
              'ADD OPTION',
              style: TextStyle(
                color: AppColors.lavenderAccent,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final canCreate = _questionCtrl.text.trim().isNotEmpty && _optionCtrls.length >= 2;
    return GestureDetector(
      onTap: (_isCreating || !canCreate) ? null : _createPoll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isCreating || !canCreate
                ? [AppColors.lavenderAccent.withValues(alpha: 0.3), AppColors.lavenderAccent.withValues(alpha: 0.3)]
                : [AppColors.lavenderAccent, const Color(0xFFc4a8ff)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: _isCreating || !canCreate
              ? []
              : [
                  BoxShadow(
                    color: AppColors.lavenderAccent.withValues(alpha: 0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 20,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCreating)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.midnightBg),
              )
            else ...[
              const Icon(Icons.add_rounded, color: AppColors.midnightBg, size: 22),
              const SizedBox(width: 8),
            ],
            Text(
              _isCreating ? 'Creating...' : 'Create Poll',
              style: const TextStyle(
                color: AppColors.midnightBg,
                fontFamily: _fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
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
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.glassBorder,
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
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PollTypeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.lavenderAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.lavenderAccent
                : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.lavenderAccent
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.lavenderAccent
                    : AppColors.textSecondary,
                fontFamily: _fontFamily,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle,
                size: 14,
                color: AppColors.lavenderAccent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
