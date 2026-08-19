import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_entity.dart';
import '../../services/auth/user_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/notification/notification_service.dart';
import '../../models/user_entity.dart';
import '../../widgets/animated_background.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _auth = FirebaseAuth.instance;
  final _userService = UserService();
  final _friendService = FriendService();
  final _notificationService = NotificationService();
  UserEntity? _user;
  bool _showNotifications = false;
  bool _loading = true;

  String get _uid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final user = await _userService.getUserDocument(uid);

    if (mounted) {
      setState(() {
        _user = user;
        _loading = false;
      });
    }
  }

  Future<void> _acceptRequest(String friendshipId, String notificationId) async {
    await _friendService.acceptRequest(friendshipId,
        acceptorUid: _uid, acceptorNotificationId: notificationId);
    _loadUser();
  }

  Future<void> _declineRequest(String friendshipId, String notificationId) async {
    await _friendService.declineRequest(friendshipId,
        declinerUid: _uid, declinerNotificationId: notificationId);
    _loadUser();
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A1450),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text(
          'Log Out',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Color(0xFFFE4EF0), fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        showStars: false,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFE4EF0)),
              )
            : _user == null
                ? const Center(
                    child: Text(
                      'No user data found',
                      style: TextStyle(color: Colors.white54, fontFamily: 'Poppins'),
                    ),
                  )
                : Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_showNotifications) {
                            setState(() => _showNotifications = false);
                          }
                        },
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Account',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  _buildNotificationBell(),
                                ],
                              ),
                              const SizedBox(height: 24),
                            _buildProfileCard(),
                            const SizedBox(height: 16),
                            _buildAccountInfoCard(),
                            const SizedBox(height: 16),
                            _buildSettingsCard(),
                            const SizedBox(height: 16),
                            _buildLogoutButton(),
                            ],
                          ),
                        ),
                      ),
                      if (_showNotifications) _buildNotificationsPanel(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildNotificationBell() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showNotifications = !_showNotifications;
        });
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: Colors.white.withValues(alpha: 0.7),
                size: 22,
              ),
            ),
            StreamBuilder<int>(
              stream: _notificationService.getUnreadCount(_uid),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFE4EF0),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return _GlassCard(
      child: Column(
        children: [
          _buildAvatar(),
          const SizedBox(height: 16),
          Text(
            _user!.displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          if (_user!.username.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '@${_user!.username}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
                fontFamily: 'Poppins',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'ID: ${_user!.userId}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _user!.email ?? 'Not provided',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final hasPhoto = _user!.photoUrl != null && _user!.photoUrl!.isNotEmpty;

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                _user!.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<List>(
      stream: _friendService.getFriendsStream(_uid),
      builder: (context, snapshot) {
        final friendsCount = snapshot.data?.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildStatItem(count: friendsCount, label: 'Friends'),
              _buildStatDivider(),
              _buildStatItem(count: 0, label: 'Mutuals'),
              _buildStatDivider(),
              _buildStatItem(count: 0, label: 'Decisions'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({required int count, required String label}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildAccountInfoCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Info',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            icon: Icons.shield_outlined,
            title: 'Auth Provider',
            subtitle: _user!.authProvider.toUpperCase(),
          ),
          _buildInfoTile(
            icon: Icons.calendar_today_outlined,
            title: 'Member Since',
            subtitle: _formatDate(_user!.createdAt),
          ),
          _buildInfoTile(
            icon: Icons.verified_outlined,
            title: 'Email Verified',
            subtitle: _user!.isEmailVerified ? 'Yes' : 'No',
            valueColor: _user!.isEmailVerified
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF9800),
          ),
          _buildInfoTile(
            icon: Icons.star_outline,
            title: 'Premium',
            subtitle: _user!.isPremium ? 'Active' : 'Free',
            valueColor: _user!.isPremium
                ? const Color(0xFFFFD700)
                : Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFFE4EF0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return _GlassCard(
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.person_add_outlined,
            title: 'Add Personal Account',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.history_outlined,
            title: 'Recent Activities',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.settings_outlined,
            title: 'Settings and Privacy',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.person_add_outlined,
            title: 'Add Account',
            onTap: () {},
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _signOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
            width: 1,
          ),
          color: const Color(0xFFFE4EF0).withValues(alpha: 0.1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Color(0xFFFE4EF0), size: 20),
            SizedBox(width: 8),
            Text(
              'Log Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFE4EF0),
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsPanel() {
    return Positioned(
      top: 70,
      right: 20,
      left: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1450).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await _notificationService.markAllAsRead(_uid);
                            },
                            child: Text(
                              'Mark all read',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () async {
                              await _notificationService.deleteReadNotifications(_uid);
                            },
                            child: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => setState(() => _showNotifications = false),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                StreamBuilder<List<NotificationEntity>>(
                  stream: _notificationService.getNotificationsStream(_uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final notifications = snapshot.data ?? [];

                    if (notifications.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(
                            color: Colors.white38,
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    return Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          return _NotificationItem(
                            notification: notif,
                            userService: _userService,
                            onAccept: notif.type == NotificationType.friendRequest
                                ? () => _acceptRequest(
                                    notif.relatedId ?? '', notif.notificationId)
                                : null,
                            onDecline: notif.type == NotificationType.friendRequest
                                ? () => _declineRequest(
                                    notif.relatedId ?? '', notif.notificationId)
                                : null,
                            onTap: () async {
                              if (!notif.isRead) {
                                await _notificationService.markAsRead(
                                    _uid, notif.notificationId);
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationEntity notification;
  final UserService userService;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onTap;

  const _NotificationItem({
    required this.notification,
    required this.userService,
    this.onAccept,
    this.onDecline,
    this.onTap,
  });

  IconData _typeIcon() {
    switch (notification.type) {
      case NotificationType.friendRequest:
        return Icons.person_add;
      case NotificationType.friendRequestAccepted:
        return Icons.check_circle;
    }
  }

  Color _typeColor() {
    switch (notification.type) {
      case NotificationType.friendRequest:
        return const Color(0xFFFE4EF0);
      case NotificationType.friendRequestAccepted:
        return const Color(0xFF4CAF50);
    }
  }

  String _timeAgo() {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _typeColor().withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(_typeIcon(), size: 18, color: _typeColor()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _timeAgo(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.4),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notification.type == NotificationType.friendRequest) ...[
                    const SizedBox(height: 8),
                    if (notification.status == NotificationStatus.accepted)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 12, color: Color(0xFF4CAF50)),
                                SizedBox(width: 4),
                                Text(
                                  'Accepted',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4CAF50),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (notification.status == NotificationStatus.declined)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cancel_outlined, size: 12, color: Colors.white54),
                                SizedBox(width: 4),
                                Text(
                                  'Declined',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white54,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          if (onAccept != null)
                            GestureDetector(
                              onTap: onAccept,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFE4EF0),
                                      Color(0xFF800DD8)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Accept',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                          if (onAccept != null && onDecline != null)
                            const SizedBox(width: 6),
                          if (onDecline != null)
                            GestureDetector(
                              onTap: onDecline,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Decline',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFE4EF0),
                  shape: BoxShape.circle,
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

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
