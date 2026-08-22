import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/poll.dart';
import '../../models/user_entity.dart';
import '../../services/poll/poll_service.dart';
import '../../services/auth/user_service.dart';
import '../../utils/constants.dart';

const _fontFamily = 'PlusJakartaSans';

class PollMessageCard extends StatefulWidget {
  final ChatPoll poll;
  final bool isMe;
  final String senderName;
  final String currentUid;
  final VoidCallback? onTap;

  const PollMessageCard({
    super.key,
    required this.poll,
    required this.isMe,
    required this.senderName,
    required this.currentUid,
    this.onTap,
  });

  @override
  State<PollMessageCard> createState() => _PollMessageCardState();
}

class _PollMessageCardState extends State<PollMessageCard> {
  final _pollService = PollService();
  final _userService = UserService();
  String? _selectedOption;
  bool _hasVoted = false;
  bool _isVoting = false;
  String? _myVote;
  Map<String, List<String>> _votersByOption = {};
  final Map<String, UserEntity> _userCache = {};
  Timer? _expiryTimer;
  late Stream<ChatPoll?> _pollStream;
  ChatPoll? _latestPoll;

  @override
  void initState() {
    super.initState();
    _latestPoll = widget.poll;
    _pollStream = _createStream();
    _checkVoteStatus();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Stream<ChatPoll?> _createStream() {
    return _pollService.getPollStream(
      widget.poll.id,
      chatId: widget.poll.chatId,
      groupId: widget.poll.groupId,
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PollMessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.id != widget.poll.id) {
      _latestPoll = widget.poll;
      _selectedOption = null;
      _hasVoted = false;
      _myVote = null;
      _votersByOption = {};
      _isVoting = false;
      _pollStream = _createStream();
      _checkVoteStatus();
      _loadVoters();
    }
  }

  Future<void> _checkVoteStatus() async {
    final hasVoted = await _pollService.hasVoted(
      widget.poll.id,
      widget.currentUid,
      chatId: widget.poll.chatId,
      groupId: widget.poll.groupId,
    );
    if (hasVoted && mounted) {
      final myVoteOption = await _pollService.getMyVoteOption(
        widget.poll.id,
        widget.currentUid,
        chatId: widget.poll.chatId,
        groupId: widget.poll.groupId,
      );
      if (mounted) {
        setState(() {
          _hasVoted = true;
          _myVote = myVoteOption;
        });
        if (widget.poll.type == PollType.public) {
          _loadVoters();
        }
      }
    }
  }

  Future<void> _loadVoters() async {
    if (widget.poll.type != PollType.public) return;
    final voters = await _pollService.getVotersByOption(
      widget.poll.id,
      chatId: widget.poll.chatId,
      groupId: widget.poll.groupId,
    );
    if (mounted) {
      setState(() => _votersByOption = voters);
      _loadAvatars(voters);
    }
  }

  Future<void> _loadAvatars(Map<String, List<String>> voters) async {
    final allUids = voters.values.expand((list) => list).toSet();
    final cache = <String, UserEntity>{};
    for (final uid in allUids) {
      if (!_userCache.containsKey(uid)) {
        final user = await _userService.getUserDocument(uid);
        if (user != null) cache[uid] = user;
      }
    }
    if (cache.isNotEmpty && mounted) {
      setState(() => _userCache.addAll(cache));
    }
  }

  Future<void> _vote(String option) async {
    final currentPoll = _latestPoll ?? widget.poll;
    if (currentPoll.isClosed || _hasVoted || _isVoting) return;

    setState(() => _isVoting = true);

    try {
      String? voterName;
      try {
        final voterDoc = await _userService.getUserDocument(widget.currentUid);
        voterName = voterDoc?.displayName ?? voterDoc?.email ?? 'Someone';
      } catch (_) {}

      if (currentPoll.type == PollType.secret) {
        await _pollService.voteSecret(
          pollId: currentPoll.id,
          uid: widget.currentUid,
          option: option,
          voterName: voterName,
          chatId: currentPoll.chatId,
          groupId: currentPoll.groupId,
        );
      } else {
        await _pollService.votePublic(
          pollId: currentPoll.id,
          uid: widget.currentUid,
          option: option,
          voterName: voterName,
          chatId: currentPoll.chatId,
          groupId: currentPoll.groupId,
        );
      }

      if (mounted) {
        setState(() {
          _hasVoted = true;
          _myVote = option;
          _selectedOption = null;
        });
        _loadVoters();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to vote: $e'),
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
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Widget _buildAvatar(String uid, double size) {
    final user = _userCache[uid];
    final photoUrl = user?.photoUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF211635),
        border: Border.all(color: AppColors.midnightBg, width: 1.5),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackAvatar(uid, size),
              )
            : _buildFallbackAvatar(uid, size),
      ),
    );
  }

  Widget _buildFallbackAvatar(String uid, double size) {
    final initials = uid.isNotEmpty ? uid.substring(0, 1).toUpperCase() : '?';
    return Container(
      color: const Color(0xFF211635),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.4,
            color: AppColors.lavenderAccent,
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildVoterAvatars(List<String> uids) {
    const maxVisible = 2;
    final visible = uids.take(maxVisible).toList();
    final remaining = uids.length - maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = visible.length - 1; i >= 0; i--)
          Padding(
            padding: EdgeInsets.only(left: i < visible.length - 1 ? -4 : 0),
            child: _buildAvatar(visible[i], 14),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lavenderAccent.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppColors.lavenderAccent.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    fontSize: 6,
                    fontFamily: _fontFamily,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lavenderAccent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatPoll?>(
      stream: _pollStream,
      initialData: _latestPoll ?? widget.poll,
      builder: (context, snapshot) {
        final poll = snapshot.data ?? _latestPoll ?? widget.poll;
        _latestPoll = poll;
        return _buildCard(poll);
      },
    );
  }

  Widget _buildCard(ChatPoll poll) {
    final isCreator = poll.createdBy == widget.currentUid;
    final showResults = _hasVoted || poll.isClosed;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.eventCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'POLL',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Center(
                          child: Text(
                            poll.question,
                            style: const TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Center(
                          child: Text(
                            poll.type == PollType.secret ? 'Secret' : 'Public',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 10,
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...poll.options.map((option) {
                          final votes = poll.votesForOption(option);
                          final total = poll.totalVotes;
                          final percentage = total > 0 ? (votes / total * 100) : 0.0;
                          final isMyVote = _myVote == option;
                          final isPreSelected = _selectedOption == option;
                          final voters = _votersByOption[option] ?? [];

                          return _buildOptionCard(
                            option: option,
                            votes: votes,
                            percentage: percentage,
                            isMyVote: isMyVote,
                            isPreSelected: isPreSelected,
                            showResults: showResults,
                            isSecret: poll.type == PollType.secret,
                            voters: voters,
                            poll: poll,
                          );
                        }),
                        if (poll.type == PollType.public) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${poll.totalVotes} vote${poll.totalVotes != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 10,
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (!showResults)
                          _buildVoteButton()
                        else if (poll.isClosed)
                          _buildClosedBadge()
                        else if (isCreator)
                          _buildCloseButton(poll),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildOptionCard({
    required String option,
    required int votes,
    required double percentage,
    required bool isMyVote,
    required bool isPreSelected,
    required bool showResults,
    required bool isSecret,
    required List<String> voters,
    required ChatPoll poll,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: showResults ? null : () => setState(() => _selectedOption = option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: showResults && isMyVote
                ? AppColors.neonMagenta.withValues(alpha: 0.15)
                : showResults
                    ? AppColors.glassBg
                    : isPreSelected
                        ? AppColors.lavenderAccent.withValues(alpha: 0.1)
                        : AppColors.glassBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: showResults && isMyVote
                  ? AppColors.neonMagenta.withValues(alpha: 0.5)
                  : isPreSelected
                      ? AppColors.lavenderAccent
                      : AppColors.glassBorder,
              width: isPreSelected || (showResults && isMyVote) ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!showResults)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPreSelected
                              ? AppColors.neonMagenta
                              : AppColors.textSecondary.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: isPreSelected
                          ? Center(
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.neonMagenta,
                                ),
                              ),
                            )
                          : null,
                    ),
                  if (showResults && isMyVote)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle,
                        size: 12,
                        color: AppColors.neonMagenta,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 13,
                        fontWeight: isMyVote || isPreSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: showResults && isMyVote
                            ? AppColors.textPrimary
                            : isPreSelected
                                ? AppColors.lavenderAccent
                                : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (showResults && poll.type == PollType.public && voters.isNotEmpty)
                    _buildVoterAvatars(voters),
                  if (showResults && votes > 0)
                    Text(
                      isSecret
                          ? '$votes (${percentage.toStringAsFixed(0)}%)'
                          : '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isMyVote
                            ? AppColors.neonMagenta
                            : AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              if (showResults && votes > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 5,
                    backgroundColor: AppColors.glassBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMyVote ? AppColors.neonMagenta : AppColors.lavenderAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteButton() {
    final canSubmit = _selectedOption != null && !_isVoting;
    return GestureDetector(
      onTap: canSubmit ? () => _vote(_selectedOption!) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 38,
        decoration: BoxDecoration(
          gradient: canSubmit
              ? const LinearGradient(
                  colors: [AppColors.lavenderAccent, Color(0xFFc4a8ff)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: canSubmit ? null : AppColors.glassBg,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: canSubmit ? AppColors.lavenderAccent : AppColors.glassBorder,
            width: 1,
          ),
          boxShadow: canSubmit
              ? [
                  BoxShadow(
                    color: AppColors.lavenderAccent.withValues(alpha: 0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: _isVoting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.midnightBg,
                  ),
                )
              : Text(
                  'Vote',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: canSubmit
                        ? AppColors.midnightBg
                        : AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildClosedBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: const Text(
          'Closed',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(ChatPoll poll) {
    return GestureDetector(
      onTap: () async {
        await _pollService.closePoll(
          pollId: poll.id,
          chatId: poll.chatId,
          groupId: poll.groupId,
        );
      },
      child: Container(
        width: double.infinity,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: const Center(
          child: Text(
            'Close',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
        ),
      ),
    );
  }
}
