import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_entity.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/user_service.dart';
import 'email_change_otp_screen.dart';

const _font = 'PlusJakartaSans';

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
      SnackBar(content: Text(message), backgroundColor: bg),
    );
  }

  // ─── Password Verification Dialog ───

  Future<String?> _showPasswordDialog({required String title}) async {
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
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
      backgroundColor: const Color(0xFF2A1450),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      backgroundColor: const Color(0xFF2A1450),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1233),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Color(0xFFFF6B6B), fontFamily: _font, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Your account will be scheduled for deletion in 24 hours. '
          'You can cancel the deletion anytime before that. '
          'After 24 hours, your account and all data will be permanently removed.',
          style: TextStyle(color: Colors.white70, fontFamily: _font, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Account', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final password = await _showPasswordDialog(title: 'Verify Password');
    if (password == null || !mounted) return;

    try {
      await _authService.reauthenticate(_email, password);
      await _userService.requestAccountDeletion(_uid);
      await _loadUser();
      _showSnack('Account scheduled for deletion in 24 hours', bg: const Color(0xFFFF6B6B));
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1233),
        title: const Text('Cancel Deletion', style: TextStyle(color: Colors.white, fontFamily: _font)),
        content: const Text(
          'Your account will no longer be deleted.',
          style: TextStyle(color: Colors.white70, fontFamily: _font),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Scheduled', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Deletion', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
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
        backgroundColor: const Color(0xFF1A0A2E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
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
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFE4EF0)))
            : RefreshIndicator(
                color: const Color(0xFFFE4EF0),
                backgroundColor: const Color(0xFF1A0A2E),
                onRefresh: _loadUser,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEmailSection(),
                      const SizedBox(height: 24),
                      _buildPasswordSection(),
                      const SizedBox(height: 24),
                      _buildDeleteSection(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEmailSection() {
    return _buildSection(
      icon: Icons.email_outlined,
      title: 'Manage Email',
      subtitle: _email,
      child: _user?.deletionRequestedAt == null
          ? _buildActionRow(
              label: 'Change Email',
              color: const Color(0xFFFE4EF0),
              onTap: _showManageEmailSheet,
            )
          : null,
    );
  }

  Widget _buildPasswordSection() {
    return _buildSection(
      icon: Icons.lock_outline,
      title: 'Change Password',
      subtitle: 'Update your account password',
      child: _user?.deletionRequestedAt == null
          ? _buildActionRow(
              label: 'Change Password',
              color: const Color(0xFF800DD8),
              onTap: _showChangePasswordSheet,
            )
          : null,
    );
  }

  Widget _buildDeleteSection() {
    final hasPendingDeletion = _user?.scheduledDeletionAt != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasPendingDeletion
            ? const Color(0xFFFF6B6B).withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPendingDeletion
              ? const Color(0xFFFF6B6B).withValues(alpha: 0.3)
              : const Color(0xFFFF6B6B).withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Account',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: _font),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasPendingDeletion) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account scheduled for deletion',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B), fontFamily: _font),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Time remaining: ${_formatDuration(_remaining)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: _font),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _cancelDeletion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF),
                  side: const BorderSide(color: Color(0xFF00E5FF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                child: const Text('Cancel Deletion', style: TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ] else ...[
            const Text(
              'Your account will be scheduled for deletion in 24 hours. You can cancel anytime before that.',
              style: TextStyle(fontSize: 13, color: Colors.white54, fontFamily: _font),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _requestDeletion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                  side: const BorderSide(color: Color(0xFFFF6B6B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                child: const Text('Request Deletion', style: TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF800DD8).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFFE4EF0), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: _font)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54, fontFamily: _font), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 16), child],
        ],
      ),
    );
  }

  Widget _buildActionRow({required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, fontFamily: _font)),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Email Sheet (self-contained, no outer context needed after return) ───

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
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: _font)),
            const SizedBox(height: 8),
            Text('Current: ${widget.currentEmail}', style: const TextStyle(fontSize: 13, color: Colors.white54, fontFamily: _font)),
            const SizedBox(height: 20),
            const Text('New Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70, fontFamily: _font)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontFamily: _font),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a new email';
                if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Enter new email address',
                hintStyle: TextStyle(color: Colors.white38, fontFamily: _font),
                filled: true,
                fillColor: const Color(0x991A0A2E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x4DFE4EF0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
                focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Current Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70, fontFamily: _font)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontFamily: _font),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
              decoration: InputDecoration(
                hintText: 'Enter current password to confirm',
                hintStyle: TextStyle(color: Colors.white38, fontFamily: _font),
                filled: true,
                fillColor: const Color(0x991A0A2E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x4DFE4EF0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
                focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF800DD8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('Update Email', style: TextStyle(fontFamily: _font, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
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
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: _font)),
            const SizedBox(height: 20),
            _buildField(ctrl: _currentPwCtrl, label: 'Current Password'),
            const SizedBox(height: 14),
            _buildField(ctrl: _newPwCtrl, label: 'New Password', validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              if (v.length < 6) return 'Must be at least 6 characters';
              return null;
            }),
            const SizedBox(height: 14),
            _buildField(ctrl: _confirmPwCtrl, label: 'Confirm New Password', validator: (v) {
              if (v != _newPwCtrl.text) return 'Passwords do not match';
              return null;
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF800DD8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('Update Password', style: TextStyle(fontFamily: _font, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController ctrl, required String label, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: true,
      style: const TextStyle(color: Colors.white, fontFamily: _font),
      validator: validator ?? ((v) => (v == null || v.isEmpty) ? 'This field is required' : null),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54, fontFamily: _font),
        filled: true,
        fillColor: const Color(0x991A0A2E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x4DFE4EF0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
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
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1233),
      title: Text(widget.title, style: const TextStyle(color: Colors.white, fontFamily: _font)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontFamily: _font),
          validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
          decoration: InputDecoration(
            hintText: 'Enter your current password',
            hintStyle: TextStyle(color: Colors.white38, fontFamily: _font),
            filled: true,
            fillColor: const Color(0x991A0A2E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x4DFE4EF0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Confirm', style: TextStyle(color: Color(0xFFFE4EF0))),
        ),
      ],
    );
  }
}
