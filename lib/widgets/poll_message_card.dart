import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/poll.dart';
import '../../models/user_entity.dart';
import '../../services/poll/poll_service.dart';
import '../../services/auth/user_service.dart';
import '../../utils/constants.dart';

const _fontFamily = 'Poppins';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _neonMagenta = Color(0xFFFE4EF0);
const _electricPurple = Color(0xFF800DD8);
const _electricCyan = Color(0xFF00E5FF);
const _cardBg = Color(0xFF1A0A2E);

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

class _PollMessageCardState extends State<PollMessageCard>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _latestPoll = widget.poll;
    _pollStream = _createStream();
    _checkVoteStatus();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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
    _pulseController.dispose();
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
    if (widget.currentUid.isEmpty) return;
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
    if (widget.currentUid.isEmpty) return;
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
            content: Text(
              'Failed to vote: $e',
              style: const TextStyle(fontFamily: _fontFamily, color: Colors.white),
            ),
            backgroundColor: _cardBg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _neonMagenta.withValues(alpha: 0.4)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  // ─── Avatar helpers ──────────────────────────────────────────────────────────

  Widget _buildAvatar(String uid, double size) {
    final user = _userCache[uid];
    final photoUrl = user?.photoUrl;
    final avatarAsset = user?.avatarAsset;
    final hasAvatarAsset = avatarAsset != null && avatarAsset.isNotEmpty;
    final hasAvatarUrl = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _cardBg,
        border: Border.all(color: _neonMagenta.withValues(alpha: 0.5), width: 1.5),
      ),
      child: ClipOval(
        child: hasAvatarAsset
            ? Image.asset(
                avatarAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackAvatar(uid, size),
              )
            : hasAvatarUrl
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_electricPurple, _neonMagenta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.4,
            color: Colors.white,
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildVoterAvatars(List<String> uids) {
    const maxVisible = 3;
    final visible = uids.take(maxVisible).toList();
    final remaining = uids.length - maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = visible.length - 1; i >= 0; i--)
          Padding(
            padding: EdgeInsets.only(left: i < visible.length - 1 ? -6.0 : 0),
            child: _buildAvatar(visible[i], 18),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_electricPurple, _neonMagenta],
                ),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    fontSize: 7,
                    fontFamily: _fontFamily,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Main build ──────────────────────────────────────────────────────────────

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
    final isSecret = poll.type == PollType.secret;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header bar ──────────────────────────────────────────────
                _buildHeader(poll, isSecret),

                // ── Options ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: poll.options.map((option) {
                      final votes = poll.votesForOption(option);
                      final total = poll.totalVotes;
                      final percentage =
                          total > 0 ? (votes / total * 100) : 0.0;
                      final isMyVote = _myVote == option;
                      final isPreSelected = _selectedOption == option;
                      final voters = _votersByOption[option] ?? [];

                      return _buildOptionRow(
                        option: option,
                        votes: votes,
                        percentage: percentage,
                        isMyVote: isMyVote,
                        isPreSelected: isPreSelected,
                        showResults: showResults,
                        isSecret: isSecret,
                        voters: voters,
                        poll: poll,
                      );
                    }).toList(),
                  ),
                ),

                // ── Footer ──────────────────────────────────────────────────
                _buildFooter(poll, showResults, isCreator),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(ChatPoll poll, bool isSecret) {
    final timeLeft = _formatTimeLeft(poll);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _electricPurple.withValues(alpha: 0.35),
            _neonMagenta.withValues(alpha: 0.18),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + POLL label + type badge
          Row(
            children: [
              // Glowing poll icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_electricPurple, _neonMagenta],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _neonMagenta.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.poll_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'POLL',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: Colors.white54,
                    ),
                  ),
                  Text(
                    'by ${widget.senderName}',
                    style: const TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 10,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSecret
                      ? _electricCyan.withValues(alpha: 0.15)
                      : _electricPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSecret
                        ? _electricCyan.withValues(alpha: 0.5)
                        : _neonMagenta.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSecret ? Icons.lock_rounded : Icons.public_rounded,
                      size: 9,
                      color: isSecret ? _electricCyan : _neonMagenta,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isSecret ? 'Secret' : 'Public',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isSecret ? _electricCyan : _neonMagenta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Question text
          Text(
            poll.question,
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          if (timeLeft != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: poll.isClosed
                          ? Colors.redAccent
                          : _electricCyan,
                      boxShadow: [
                        BoxShadow(
                          color: (poll.isClosed
                                  ? Colors.redAccent
                                  : _electricCyan)
                              .withValues(alpha: _pulseAnim.value * 0.8),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  timeLeft,
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: poll.isClosed
                        ? Colors.redAccent.withValues(alpha: 0.8)
                        : _electricCyan.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _formatTimeLeft(ChatPoll poll) {
    if (poll.isClosed) return 'Poll Closed';
    if (poll.closesAt == null) return null;
    final diff = poll.closesAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Poll Closed';
    if (diff.inDays > 0) return 'Ends in ${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return 'Ends in ${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return 'Ends in ${diff.inMinutes}m';
    return 'Ends in ${diff.inSeconds}s';
  }

  // ─── Option row ──────────────────────────────────────────────────────────────

  Widget _buildOptionRow({
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
    // Determine accent color for this option
    final accent = isMyVote ? _neonMagenta : _electricCyan;
    final borderColor = isMyVote
        ? _neonMagenta.withValues(alpha: 0.7)
        : isPreSelected
            ? AppColors.lavenderAccent.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: showResults ? null : () => setState(() => _selectedOption = option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isMyVote
                ? _neonMagenta.withValues(alpha: 0.12)
                : isPreSelected
                    ? AppColors.lavenderAccent.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: isMyVote || isPreSelected
                ? [
                    BoxShadow(
                      color: (isMyVote ? _neonMagenta : AppColors.lavenderAccent)
                          .withValues(alpha: 0.18),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Gradient fill bar (results)
                if (showResults && percentage > 0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: percentage / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isMyVote
                                  ? [
                                      _electricPurple.withValues(alpha: 0.35),
                                      _neonMagenta.withValues(alpha: 0.25),
                                    ]
                                  : [
                                      _electricCyan.withValues(alpha: 0.18),
                                      _electricCyan.withValues(alpha: 0.08),
                                    ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Radio / checkmark
                      if (!showResults)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPreSelected
                                  ? _neonMagenta
                                  : Colors.white.withValues(alpha: 0.35),
                              width: 1.8,
                            ),
                            color: isPreSelected
                                ? _neonMagenta.withValues(alpha: 0.15)
                                : Colors.transparent,
                          ),
                          child: isPreSelected
                              ? const Center(
                                  child: Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: _neonMagenta,
                                  ),
                                )
                              : null,
                        )
                      else if (isMyVote)
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _neonMagenta.withValues(alpha: 0.2),
                            border: Border.all(
                              color: _neonMagenta,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: _neonMagenta,
                          ),
                        ),
                      // Option text
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            fontSize: 13,
                            fontWeight: isMyVote || isPreSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isMyVote
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Voter avatars (public only)
                      if (showResults &&
                          poll.type == PollType.public &&
                          voters.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildVoterAvatars(voters),
                        ),
                      // Percentage pill
                      if (showResults)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isSecret && votes > 0
                                ? '$votes · ${percentage.toStringAsFixed(0)}%'
                                : '${percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
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

  // ─── Footer ──────────────────────────────────────────────────────────────────

  Widget _buildFooter(ChatPoll poll, bool showResults, bool isCreator) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vote count row
          Row(
            children: [
              Icon(
                Icons.how_to_vote_rounded,
                size: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                '${poll.totalVotes} vote${poll.totalVotes != 1 ? 's' : ''}',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const Spacer(),
              if (!showResults && _selectedOption != null)
                Text(
                  'Tap Vote to confirm',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 10,
                    color: AppColors.lavenderAccent.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Action button
          if (!showResults)
            _buildVoteButton()
          else if (poll.isClosed)
            _buildClosedBadge()
          else if (isCreator && !poll.isClosed)
            _buildCloseButton(poll),
        ],
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
        height: 42,
        decoration: BoxDecoration(
          gradient: canSubmit
              ? const LinearGradient(
                  colors: [_electricPurple, _neonMagenta],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: canSubmit ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: canSubmit
                ? _neonMagenta.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: canSubmit
              ? [
                  BoxShadow(
                    color: _neonMagenta.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: _isVoting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.how_to_vote_rounded,
                      size: 16,
                      color: canSubmit
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cast Vote',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: canSubmit
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildClosedBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 5),
            Text(
              'Poll Closed',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
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
        height: 38,
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stop_circle_outlined,
                size: 14,
                color: Colors.redAccent.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                'Close Poll',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

