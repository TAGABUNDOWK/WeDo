import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/poll.dart';
import '../../../models/user_entity.dart';
import '../../../services/poll/poll_service.dart';
import '../../../services/auth/user_service.dart';
import '../../../services/group/group_service.dart';

class PollDetailScreen extends StatefulWidget {
  final String pollId;
  final String? groupId;
  final String? chatId;

  const PollDetailScreen({
    super.key,
    required this.pollId,
    this.groupId,
    this.chatId,
  });

  @override
  State<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends State<PollDetailScreen> {
  final _pollService = PollService();
  final _userService = UserService();
  final _groupService = GroupService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  ChatPoll? _poll;
  Map<String, String> _memberNames = {};
  Map<String, List<String>> _votersByOption = {};
  final Map<String, UserEntity> _userCache = {};
  bool _isLoading = true;
  bool _hasVoted = false;
  String? _myVote;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool skipVoteCheck = false}) async {
    final poll = await _pollService.getPoll(
      widget.pollId,
      chatId: widget.chatId,
      groupId: widget.groupId,
    );

    if (poll == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    Map<String, String> names = {};
    if (widget.groupId != null) {
      final members = await _groupService.getGroupMembersWithNames(widget.groupId!);
      for (final m in members) {
        names[m['uid'] as String] = m['displayName'] as String;
      }
    }

    bool hasVoted = _hasVoted;
    if (!skipVoteCheck) {
      hasVoted = await _pollService.hasVoted(
        widget.pollId,
        _currentUser?.uid ?? '',
        chatId: widget.chatId,
        groupId: widget.groupId,
      );
    }

    Map<String, List<String>> voters = {};
    if (poll.type == PollType.public) {
      voters = await _pollService.getVotersByOption(
        widget.pollId,
        chatId: widget.chatId,
        groupId: widget.groupId,
      );

      final allUids = voters.values.expand((list) => list).toSet();
      final cache = <String, UserEntity>{};
      for (final uid in allUids) {
        if (!_userCache.containsKey(uid)) {
          final user = await _userService.getUserDocument(uid);
          if (user != null) cache[uid] = user;
        }
      }
      if (cache.isNotEmpty) _userCache.addAll(cache);
    }

    if (mounted) {
      setState(() {
        _poll = poll;
        _memberNames = names;
        _hasVoted = hasVoted;
        _votersByOption = voters;
        _isLoading = false;
      });
    }
  }

  Future<void> _vote(String option) async {
    if (_poll == null || _poll!.isClosed || _hasVoted) return;

    if (_poll!.type == PollType.secret) {
      await _pollService.voteSecret(
        pollId: _poll!.id,
        uid: _currentUser?.uid ?? '',
        option: option,
        chatId: widget.chatId,
        groupId: widget.groupId,
      );
    } else {
      await _pollService.votePublic(
        pollId: _poll!.id,
        uid: _currentUser?.uid ?? '',
        option: option,
        chatId: widget.chatId,
        groupId: widget.groupId,
      );
    }

    setState(() {
      _hasVoted = true;
      _myVote = option;
    });
    _loadData(skipVoteCheck: true);
  }

  Future<void> _closePoll() async {
    if (_poll == null) return;
    await _pollService.closePoll(
      pollId: _poll!.id,
      chatId: widget.chatId,
      groupId: widget.groupId,
    );
    _loadData();
  }

  Widget _buildAvatar(String uid, double size) {
    final user = _userCache[uid];
    final photoUrl = user?.photoUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
        border: Border.all(color: Colors.white, width: 1.5),
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
      color: Colors.deepPurple.shade200,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.4,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildVoterAvatars(List<String> uids) {
    const maxVisible = 4;
    final visible = uids.take(maxVisible).toList();
    final remaining = uids.length - maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = visible.length - 1; i >= 0; i--)
          Padding(
            padding: EdgeInsets.only(left: i < visible.length - 1 ? -6 : 0),
            child: _buildAvatar(visible[i], 24),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_poll?.type == PollType.secret ? 'Secret Vote' : 'Poll'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_poll != null &&
              _poll!.createdBy == _currentUser?.uid &&
              !_poll!.isClosed)
            TextButton(
              onPressed: _closePoll,
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _poll == null
              ? const Center(child: Text('Poll not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            _poll!.question,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _poll!.type == PollType.secret
                                ? 'Anonymous poll'
                                : 'Created by ${_memberNames[_poll!.createdBy] ?? _poll!.createdBy}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ..._poll!.options.map((option) {
                          final votes = _poll!.votesForOption(option);
                          final total = _poll!.totalVotes;
                          final percentage = total > 0 ? (votes / total * 100) : 0.0;
                          final isSelected = _myVote == option;
                          final showResults = _hasVoted || _poll!.isClosed;
                          final voters = _votersByOption[option] ?? [];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (showResults)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: percentage / 100,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                                                ),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _poll!.type == PollType.secret
                                            ? '$votes (${percentage.toStringAsFixed(0)}%)'
                                            : '${percentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      if (_poll!.type == PollType.public && voters.isNotEmpty) ...[
                                        const SizedBox(width: 10),
                                        _buildVoterAvatars(voters),
                                      ],
                                    ],
                                  )
                                else
                                  GestureDetector(
                                    onTap: () => _vote(option),
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            '${_poll!.totalVotes} vote${_poll!.totalVotes != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        if (_poll!.closesAt != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              _poll!.isClosed ? 'Poll closed' : 'Closes at ${_poll!.closesAt}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
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
}
