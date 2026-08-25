import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/group/group_service.dart';
import '../../utils/constants.dart';
import '../screens/chat/group/group_chat_screen.dart';

const _fontFamily = 'PlusJakartaSans';

class GroupInviteMessageCard extends StatelessWidget {
  final String groupId;
  final bool isMe;
  final String? senderName;
  final String time;
  final Map<String, dynamic>? groupInviteData;

  const GroupInviteMessageCard({
    super.key,
    required this.groupId,
    required this.isMe,
    this.senderName,
    required this.time,
    this.groupInviteData,
  });

  @override
  Widget build(BuildContext context) {
    final groupName = groupInviteData?['groupName'] as String? ?? 'Group';
    final memberCount = groupInviteData?['memberCount'] as int? ?? 0;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
                child: Text(
                  senderName!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
            _InviteCard(
              groupId: groupId,
              groupName: groupName,
              memberCount: memberCount,
              groupInviteData: groupInviteData,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatefulWidget {
  final String groupId;
  final String groupName;
  final int memberCount;
  final Map<String, dynamic>? groupInviteData;

  const _InviteCard({
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    this.groupInviteData,
  });

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  bool _isLoading = false;

  Future<void> _onTap() async {
    if (_isLoading) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final service = GroupService();
      final group = await service.getGroup(widget.groupId);

      if (group == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group not found')),
          );
        }
        return;
      }

      final isMember = group.members.contains(currentUser.uid);

      if (!isMember) {
        final displayName = currentUser.displayName ?? currentUser.email ?? 'User';

        await service.addMember(
          groupId: widget.groupId,
          memberUid: currentUser.uid,
          displayName: displayName,
          invitedBy: widget.groupInviteData?['senderId'] as String? ?? 'link',
        );

        try {
          await service.sendSystemMessage(
            groupId: widget.groupId,
            content: '$displayName joined the group via invite link',
            senderName: '',
          );
        } catch (_) {}
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupChatScreen(groupId: widget.groupId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF211635),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(widget.groupName),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader(String groupName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3A1078),
            Color(0xFF800DD8),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            groupName,
            style: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.memberCount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(
                  '${widget.memberCount} member${widget.memberCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          const Text(
            'Join this group chat and be part of the conversation',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _isLoading ? null : _onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFE4EF0),
                    Color(0xFF800DD8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
                    offset: const Offset(0, 3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'View Chat',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
