import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_entity.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/user_service.dart';
import '../../widgets/animated_background.dart';
import 'email_change_otp_screen.dart';

const _font = 'Poppins';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _auth = FirebaseAuth.instance;
  final _authService = AuthService();
  final _userService = UserService();
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  UserEntity? _user;
  bool _loading = true;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  String get _uid => _auth.currentUser?.uid ?? '';
  String get _email => _user?.email ?? _auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await _userService.getUserDocument(_uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
    _startCountdownIfNeeded();
  }

  void _startCountdownIfNeeded() {
    if (_user?.scheduledDeletionAt == null) return;
    _countdownTimer?.cancel();
    _updateRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
      if (_remaining <= Duration.zero) {
        _countdownTimer?.cancel();
      }
    });
  }

  void _updateRemaining() {
    final scheduled = _user?.scheduledDeletionAt;
    if (scheduled == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }
    final diff = scheduled.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  void _showSnack(String message, {Color bg = const Color(0xFF800DD8)}) {
    if (!mounted) return;
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: _font, color: Colors.white),
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Password Verification Dialog ───

  Future<String?> _showPasswordDialog({required String title}) async {
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => _PasswordDialog(title: title),
    );
  }

  // ─── Manage Email ───

  Future<void> _showManageEmailSheet() async {
    if (!mounted) return;
    final user = _auth.currentUser;
    final currentEmail = user?.email ?? '';

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _EmailSheet(currentEmail: currentEmail),
    );

    if (result == null || !mounted) return;
    final newEmail = result['email'] ?? '';
    final password = result['password'] ?? '';
    if (newEmail.isEmpty || newEmail == currentEmail) return;

    try {
      await _authService.reauthenticate(currentEmail, password);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Failed to verify password', bg: Colors.redAccent);
      return;
    } catch (e) {
      _showSnack(e.toString(), bg: Colors.redAccent);
      return;
    }

    if (!mounted) return;

    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EmailChangeOtpScreen(
          userId: _uid,
          newEmail: newEmail,
        ),
      ),
    );

    if (verified == true) {
      await _loadUser();
    }
  }

  // ─── Change Password ───

  Future<void> _showChangePasswordSheet() async {
    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _PasswordChangeSheet(),
    );

    if (result == null || !mounted) return;
    final currentPw = result['current'] ?? '';
    final newPw = result['new'] ?? '';
    final confirmPw = result['confirm'] ?? '';

    if (newPw.length < 6) {
      _showSnack('New password must be at least 6 characters', bg: Colors.redAccent);
      return;
    }
    if (newPw != confirmPw) {
      _showSnack('Passwords do not match', bg: Colors.redAccent);
      return;
    }

    try {
      await _authService.reauthenticate(_email, currentPw);
      await _authService.updatePassword(newPw);
      if (!mounted) return;
      _showSnack('Password updated successfully');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Failed to change password', bg: Colors.redAccent);
    } catch (e) {
      _showSnack(e.toString(), bg: Colors.redAccent);
    }
  }

  // ─── Delete Account ───

  Future<void> _requestDeletion() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1F0F35).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.warning_rounded,
                      color: Color(0xFFFF5252),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: _font,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account will be scheduled for deletion in 24 hours. You can cancel anytime before that. After 24 hours, all your data will be permanently wiped.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    fontFamily: _font,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Keep Account',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              fontFamily: _font,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Schedule Delete',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: _font,
                            ),
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
      ),
    );

    if (confirmed != true || !mounted) return;

    final password = await _showPasswordDialog(title: 'Verify Password');
    if (password == null || !mounted) return;

    try {
      await _authService.reauthenticate(_email, password);
      await _userService.requestAccountDeletion(_uid);
      await _loadUser();
      _showSnack('Account scheduled for deletion in 24 hours', bg: const Color(0xFFFF5252));
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Failed to request deletion', bg: Colors.redAccent);
    } catch (e) {
      _showSnack(e.toString(), bg: Colors.redAccent);
    }
  }

  Future<void> _cancelDeletion() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1F0F35).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.restore_rounded,
                      color: Color(0xFF00E5FF),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cancel Deletion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: _font,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account will no longer be deleted and your data remains safe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    fontFamily: _font,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Keep Scheduled',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              fontFamily: _font,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Restore Account',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              fontFamily: _font,
                            ),
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
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _userService.cancelAccountDeletion(_uid);
      await _loadUser();
      _showSnack('Account deletion cancelled', bg: const Color(0xFF00E5FF));
    } catch (e) {
      _showSnack(e.toString(), bg: Colors.redAccent);
    }
  }

  // ─── UI ───

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
          title: const Text(
            'Account Info',
            style: TextStyle(
              fontFamily: _font,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        body: AnimatedBackground(
          showStars: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFE4EF0)))
              : RefreshIndicator(
                  color: const Color(0xFFFE4EF0),
                  backgroundColor: const Color(0xFF1A0A2E),
                  onRefresh: _loadUser,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSecurityOverviewCard(),
                        const SizedBox(height: 18),
                        _buildEmailSection(),
                        const SizedBox(height: 18),
                        _buildPasswordSection(),
                        const SizedBox(height: 18),
                        _buildDeleteSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSecurityOverviewCard() {
    final hasPendingDeletion = _user?.scheduledDeletionAt != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF800DD8), Color(0xFFFE4EF0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user?.displayName.isNotEmpty == true
                          ? _user!.displayName
                          : 'Account Security',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: _font,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasPendingDeletion
                                ? const Color(0xFFFF5252)
                                : const Color(0xFF00E5FF),
                            boxShadow: [
                              BoxShadow(
                                color: (hasPendingDeletion
                                        ? const Color(0xFFFF5252)
                                        : const Color(0xFF00E5FF))
                                    .withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasPendingDeletion
                              ? 'Deletion Pending'
                              : 'Account Active & Protected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: hasPendingDeletion
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFF00E5FF),
                            fontFamily: _font,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSection() {
    return _buildSection(
      icon: Icons.alternate_email_rounded,
      accentColor: const Color(0xFFFE4EF0),
      title: 'Email Address',
      subtitle: _email.isNotEmpty ? _email : 'No email linked',
      badgeText: 'Primary',
      actionLabel: 'Change Email',
      actionIcon: Icons.edit_rounded,
      onTap: _user?.deletionRequestedAt == null ? _showManageEmailSheet : null,
    );
  }

  Widget _buildPasswordSection() {
    return _buildSection(
      icon: Icons.lock_outline_rounded,
      accentColor: const Color(0xFF00E5FF),
      title: 'Password',
      subtitle: '••••••••••••',
      badgeText: 'Encrypted',
      actionLabel: 'Change Password',
      actionIcon: Icons.key_rounded,
      onTap: _user?.deletionRequestedAt == null ? _showChangePasswordSheet : null,
    );
  }

  Widget _buildDeleteSection() {
    final hasPendingDeletion = _user?.scheduledDeletionAt != null;
    const accentColor = Color(0xFFFF5252);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: hasPendingDeletion
                ? accentColor.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasPendingDeletion
                  ? accentColor.withValues(alpha: 0.4)
                  : accentColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.12),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: _font,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Irreversible action after grace period',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white54,
                            fontFamily: _font,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (hasPendingDeletion) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: accentColor, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Account Scheduled for Deletion',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                              fontFamily: _font,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Time remaining: ${_formatDuration(_remaining)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontFamily: _font,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'You can cancel anytime before the timer runs out.',
                        style: TextStyle(fontSize: 11, color: Colors.white60, fontFamily: _font),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _cancelDeletion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Cancel Deletion',
                      style: TextStyle(
                        fontFamily: _font,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'Your account will be scheduled for deletion in 24 hours. You can cancel anytime before the period ends.',
                  style: TextStyle(fontSize: 12, color: Colors.white54, fontFamily: _font, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _requestDeletion,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor.withValues(alpha: 0.5), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: accentColor.withValues(alpha: 0.08),
                    ),
                    child: const Text(
                      'Request Account Deletion',
                      style: TextStyle(
                        fontFamily: _font,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
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

  Widget _buildSection({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required String actionLabel,
    required IconData actionIcon,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.12),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontFamily: _font,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                  fontFamily: _font,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white60,
                            fontFamily: _font,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    splashColor: accentColor.withValues(alpha: 0.15),
                    highlightColor: accentColor.withValues(alpha: 0.08),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(actionIcon, size: 16, color: accentColor),
                              const SizedBox(width: 8),
                              Text(
                                actionLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                  fontFamily: _font,
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.chevron_right_rounded, color: accentColor, size: 20),
                        ],
                      ),
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

// ─── Email Sheet (self-contained) ───

class _EmailSheet extends StatefulWidget {
  final String currentEmail;
  const _EmailSheet({required this.currentEmail});

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  final _newEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _newEmailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'email': _newEmailCtrl.text.trim(),
      'password': _passwordCtrl.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1035).withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
            left: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Change Email',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: _font,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'A verification code will be sent to your new email.',
                style: TextStyle(fontSize: 12, color: Colors.white54, fontFamily: _font),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 16, color: Colors.white54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current: ${widget.currentEmail}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: _font),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontFamily: _font, fontSize: 14),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a new email';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                  if (v.trim() == widget.currentEmail) return 'New email cannot be the same as current';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'New Email Address',
                  hintText: 'name@example.com',
                  labelStyle: const TextStyle(color: Colors.white60, fontFamily: _font, fontSize: 13),
                  hintStyle: const TextStyle(color: Colors.white30, fontFamily: _font, fontSize: 13),
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFFFE4EF0), size: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white, fontFamily: _font, fontSize: 14),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  hintText: 'Enter password to confirm',
                  labelStyle: const TextStyle(color: Colors.white60, fontFamily: _font, fontSize: 13),
                  hintStyle: const TextStyle(color: Colors.white30, fontFamily: _font, fontSize: 13),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFFE4EF0), size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFE4EF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    shadowColor: const Color(0xFFFE4EF0).withValues(alpha: 0.5),
                  ),
                  child: const Text(
                    'Continue with Verification',
                    style: TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Password Change Sheet (self-contained) ───

class _PasswordChangeSheet extends StatefulWidget {
  const _PasswordChangeSheet();

  @override
  State<_PasswordChangeSheet> createState() => _PasswordChangeSheetState();
}

class _PasswordChangeSheetState extends State<_PasswordChangeSheet> {
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'current': _currentPwCtrl.text,
      'new': _newPwCtrl.text,
      'confirm': _confirmPwCtrl.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1035).withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
            left: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: _font,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Must be at least 6 characters long.',
                style: TextStyle(fontSize: 12, color: Colors.white54, fontFamily: _font),
              ),
              const SizedBox(height: 18),
              _buildField(
                ctrl: _currentPwCtrl,
                label: 'Current Password',
                obscureText: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 14),
              _buildField(
                ctrl: _newPwCtrl,
                label: 'New Password',
                obscureText: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new password';
                  if (v.length < 6) return 'Must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(
                ctrl: _confirmPwCtrl,
                label: 'Confirm New Password',
                obscureText: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) {
                  if (v != _newPwCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF800DD8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    shadowColor: const Color(0xFF800DD8).withValues(alpha: 0.5),
                  ),
                  child: const Text(
                    'Update Password',
                    style: TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontFamily: _font, fontSize: 14),
      validator: validator ?? ((v) => (v == null || v.isEmpty) ? 'This field is required' : null),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontFamily: _font, fontSize: 13),
        hintStyle: const TextStyle(color: Colors.white30, fontFamily: _font, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00E5FF), size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.white54,
            size: 18,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Password Dialog (self-contained) ───

class _PasswordDialog extends StatefulWidget {
  final String title;
  const _PasswordDialog({required this.title});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1F0F35).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFFFE4EF0).withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.key_rounded,
                      color: Color(0xFFFE4EF0),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: _font,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please enter your password to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    fontFamily: _font,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _ctrl,
                  obscureText: _obscure,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontFamily: _font, fontSize: 14),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    hintStyle: const TextStyle(color: Colors.white30, fontFamily: _font, fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFFE4EF0), size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              fontFamily: _font,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _submit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF800DD8), Color(0xFFFE4EF0)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFE4EF0).withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: _font,
                            ),
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
      ),
    );
  }
}
