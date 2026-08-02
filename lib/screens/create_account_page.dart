import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/user_service.dart';
import '../services/location/location_service.dart';
import '../models/user_entity.dart';
import 'otp_verification_page.dart';

enum _LocationDialogAction { retry, openSettings }

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _authService = AuthService();
  final _userService = UserService();
  final _locationService = LocationService();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final position = await _requireLocation();

      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;
      final username = _usernameCtrl.text.trim().toLowerCase();

      final credential = await _authService.signUp(email, pass);
      final userId = credential.user!.uid;

      final user = UserEntity(
        userId: userId,
        displayName: username,
        username: username,
        usernameLower: username,
        email: email,
        authProvider: 'email',
        isPremium: false,
        createdAt: DateTime.now(),
        isGuest: false,
        lastActiveAt: DateTime.now(),
        isEmailVerified: false,
      );

      await _userService.createUserDocument(user);

      if (position != null) {
        try {
          await _userService.updateLocationIfNeeded(
            userId,
            position.latitude,
            position.longitude,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Couldn\'t save your location right now'),
              ),
            );
          }
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            userId: userId,
            email: email,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position?> _requireLocation() async {
    var hasAsked = false;
    while (true) {
      if (!mounted) return null;

      final permission = await _locationService.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      if (granted) {
        return _locationService.getQuickPosition();
      }

      final enabled = await _locationService.isLocationServiceEnabled();
      if (!enabled) {
        final action = await _showLocationDialog(
          title: 'Location services off',
          message:
              'Your device location services are turned off. Turn them on to find people near you.',
          showRetry: true,
          showSettings: true,
        );
        if (action == _LocationDialogAction.openSettings) {
          await _locationService.openLocationSettings();
        }
        continue;
      }

      if (permission == LocationPermission.deniedForever) {
        await _showLocationDialog(
          title: 'Location blocked',
          message:
              'Location access is blocked. Open your device settings to allow WeDo to use your location.',
          showSettings: true,
        );
        await _locationService.openLocationSettings();
        continue;
      }

      if (!hasAsked) {
        await _showExplainDialog();
        await _locationService.requestPermission();
        hasAsked = true;
        continue;
      }

      final action = await _showLocationDialog(
        title: 'Location required',
        message:
            'We still don\'t have your location. Allow access to continue creating your account.',
        showRetry: true,
        showSettings: true,
      );
      if (action == _LocationDialogAction.openSettings) {
        await _locationService.openLocationSettings();
        continue;
      }
      await _locationService.requestPermission();
    }
  }

  Future<void> _showExplainDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFE7ECEF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enable Location'),
        content: const Text(
          'WeDo needs your location to show friends and study places near you, and so others can find you.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Enable Location'),
          ),
        ],
      ),
    );
  }

  Future<_LocationDialogAction?> _showLocationDialog({
    required String title,
    required String message,
    bool showRetry = false,
    bool showSettings = false,
  }) {
    return showDialog<_LocationDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFE7ECEF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          if (showRetry)
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _LocationDialogAction.retry,
              ),
              child: const Text('Try Again'),
            ),
          if (showSettings)
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _LocationDialogAction.openSettings,
              ),
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }

  BoxDecoration _neumorphicDecoration({Color? color}) {
    final base = color ?? const Color(0xFFE7ECEF);
    return BoxDecoration(
      color: base,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0xFFFFFFFF),
          offset: Offset(-6, -6),
          blurRadius: 12,
        ),
        BoxShadow(
          color: Color(0xFFB8C6CC),
          offset: Offset(6, 6),
          blurRadius: 12,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFE7ECEF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFE7ECEF);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: _neumorphicDecoration(color: bg),
                  child: const Center(
                    child: Icon(Icons.person_add_alt_1, size: 60, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Create Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Sign up to get started', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _neumorphicDecoration(color: bg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: _inputDecoration('Username'),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Enter a username';
                            if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(value)) {
                              return '3-20 chars, lowercase letters, numbers, _';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration('Email'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter email';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: true,
                          decoration: _inputDecoration('Password'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter password';
                            if (v.length < 6) return 'Password too short';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPassCtrl,
                          obscureText: true,
                          decoration: _inputDecoration('Confirm Password'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Confirm your password';
                            if (v != _passCtrl.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: _isLoading ? null : _onSubmit,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _isLoading ? Colors.blue.shade200 : Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFF2A6FD6),
                                  offset: Offset(0, 6),
                                  blurRadius: 10,
                                )
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Create Account',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
