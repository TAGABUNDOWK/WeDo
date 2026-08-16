import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/otp_service.dart';
import '../../services/auth/user_service.dart';
import '../../services/location/location_service.dart';
import '../../models/user_entity.dart';
import '../../widgets/animated_background.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────

class _Tokens {
  _Tokens._();

  static const pink = Color(0xFFFE4EF0);
  static const purple = Color(0xFF800DD8);
  static const darkBg = Color(0xFF1A0A2E);
  static const fieldFill = Color(0x991A0A2E);
  static const fieldBorder = Color(0x4DFE4EF0);
  static const mutedWhite = Color(0xB3FFFFFF);
  static const white = Colors.white;

  static const inputRadius = BorderRadius.all(Radius.circular(16));
  static const buttonRadius = BorderRadius.all(Radius.circular(28));
  static const fieldGap = SizedBox(height: 20);
  static const sectionGap = SizedBox(height: 28);
  static const smallGap = SizedBox(height: 8);

  static const poppins = TextStyle(fontFamily: 'Poppins');

  static TextStyle get heading =>
      poppins.copyWith(fontSize: 26, fontWeight: FontWeight.bold, color: white);

  static TextStyle get subHeading =>
      poppins.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: white);

  static TextStyle get description =>
      poppins.copyWith(fontSize: 14, color: mutedWhite, height: 1.4);

  static TextStyle get label => poppins.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: white.withOpacity(0.9),
  );

  static TextStyle get helper =>
      poppins.copyWith(fontSize: 12, color: pink.withOpacity(0.8));

  static TextStyle get fieldInput =>
      poppins.copyWith(fontSize: 15, color: white);

  static TextStyle get buttonText =>
      poppins.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: white);
}

// ─── Reusable Input Decoration ───────────────────────────────────────────────

InputDecoration _pillDecoration({
  required String label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? helperText,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: _Tokens.label,
    hintText: hint,
    hintStyle: _Tokens.poppins.copyWith(
      fontSize: 14,
      color: Colors.white.withOpacity(0.35),
    ),
    helperText: helperText,
    helperStyle: _Tokens.helper,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: _Tokens.fieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: _Tokens.fieldBorder, width: 1),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: _Tokens.pink, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: Colors.redAccent, width: 1),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
    ),
    errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
  );
}

// ─── Reusable Button ─────────────────────────────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    this.isLoading = false,
    this.onTap,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isLoading
                  ? [Colors.grey.shade600, Colors.grey.shade500]
                  : [_Tokens.purple, _Tokens.pink],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: _Tokens.buttonRadius,
            boxShadow: [
              BoxShadow(
                color: (widget.isLoading ? Colors.grey : _Tokens.pink)
                    .withOpacity(0.4),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(widget.label, style: _Tokens.buttonText),
          ),
        ),
      ),
    );
  }
}

// ─── Progress Tracker ────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int currentStep; // 0, 1, 2
  static const _labels = ['Email', 'Verification', 'Profile'];

  const _StepProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final isActive = i == currentStep;
        final isComplete = i < currentStep;

        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isComplete
                        ? _Tokens.pink
                        : _Tokens.mutedWhite.withOpacity(0.25),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (isActive || isComplete)
                          ? const LinearGradient(
                              colors: [_Tokens.purple, _Tokens.pink],
                            )
                          : null,
                      color: (isActive || isComplete)
                          ? null
                          : Colors.transparent,
                      border: (isActive || isComplete)
                          ? null
                          : Border.all(
                              color: _Tokens.mutedWhite.withOpacity(0.35),
                              width: 1.5,
                            ),
                    ),
                    child: Center(
                      child: isComplete
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : Text(
                              '${i + 1}',
                              style: _Tokens.poppins.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? Colors.white
                                    : _Tokens.mutedWhite.withOpacity(0.6),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: _Tokens.poppins.copyWith(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? _Tokens.pink
                          : _Tokens.mutedWhite.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isComplete
                        ? _Tokens.pink
                        : _Tokens.mutedWhite.withOpacity(0.25),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Main Registration Flow ──────────────────────────────────────────────────

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  int _currentStep = 0;
  String _verifiedEmail = '';
  String _verifiedUserId = '';
  bool _otpSent = false;

  static const _stepHeadings = [
    (
      title: 'Create Account',
      description:
          'Your email is your account key — we\'ll send a 6-digit code to confirm it.',
    ),
    (
      title: 'Email verification code',
      description:
          'Your email is your account key — we\'ll send a 6-digit code to confirm it.',
    ),
    (
      title: 'Personal Information',
      description:
          'A few details so we can get to know you better and personalize your experience.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: Stack(
          children: [
            // Decorative overlays (matching login)
            Positioned(
              top: 60,
              left: -300,
              child: Transform.rotate(
                angle: -0.285,
                child: Opacity(
                  opacity: 0.05,
                  child: Image.asset(
                    'assets/images/Ears-overlay1.png',
                    width: 800,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -10,
              right: -255,
              child: Transform.rotate(
                angle: -0.3454,
                child: Opacity(
                  opacity: 0.05,
                  child: Image.asset(
                    'assets/images/Eyes-overlay1.png',
                    width: 750,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Logo + Wordmark (matching login exactly)
                  Padding(
                    padding: const EdgeInsets.only(left: 14, right: 24),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/WeDo-Logo.png',
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [_Tokens.pink, _Tokens.purple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'WeDo',
                            style: TextStyle(
                              fontSize: 48,
                              fontFamily: 'PressStart2P',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // GET STARTED label
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'GET STARTED',
                        style: _Tokens.poppins.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _Tokens.pink,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 1),

                  // Step heading + description (shared across steps)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stepHeadings[_currentStep].title,
                          style: _Tokens.heading,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _stepHeadings[_currentStep].description,
                          style: _Tokens.description,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress tracker
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: _StepProgress(currentStep: _currentStep),
                  ),

                  const SizedBox(height: 2),

                  // Step content with animated transitions
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) {
                          final isNewChild =
                              child.key == ValueKey(_currentStep);
                          final offset = isNewChild
                              ? const Offset(0.3, 0.0)
                              : const Offset(-0.3, 0.0);
                          return SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: offset,
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _buildStep(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _Step1Email(
          key: const ValueKey(0),
          onEmailSubmitted: (email, userId) {
            setState(() {
              _verifiedEmail = email;
              _verifiedUserId = userId;
              _otpSent = true;
              _currentStep = 1;
            });
          },
        );
      case 1:
        return _Step2Otp(
          key: const ValueKey(1),
          email: _verifiedEmail,
          userId: _verifiedUserId,
          otpSent: _otpSent,
          onVerified: () {
            setState(() {
              _otpSent = true;
              _currentStep = 2;
            });
          },
          onOtpSent: () {
            setState(() => _otpSent = true);
          },
        );
      case 2:
        return _Step3Profile(
          key: const ValueKey(2),
          email: _verifiedEmail,
          userId: _verifiedUserId,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Step 1: Email Input ─────────────────────────────────────────────────────

class _Step1Email extends StatefulWidget {
  final void Function(String email, String userId) onEmailSubmitted;

  const _Step1Email({super.key, required this.onEmailSubmitted});

  @override
  State<_Step1Email> createState() => _Step1EmailState();
}

class _Step1EmailState extends State<_Step1Email> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _authService = AuthService();
  final _otpService = OtpService();
  final _userService = UserService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      String userId;

      debugPrint('[OTP FLOW] Step 1: Starting for email=$email');

      try {
        final credential = await _authService.signUp(
          email,
          'temp_placeholder_otp',
        );
        userId = credential.user!.uid;
        debugPrint('[OTP FLOW] signUp SUCCESS: userId=$userId');
      } catch (signUpError) {
        final msg = signUpError.toString();
        debugPrint('[OTP FLOW] signUp FAILED: $msg');
        if (msg.contains('email-already-in-use')) {
          debugPrint('[OTP FLOW] Email already in use, trying signIn...');
          try {
            final credential = await _authService.signIn(
              email,
              'temp_placeholder_otp',
            );
            userId = credential.user!.uid;
            debugPrint('[OTP FLOW] signIn SUCCESS: userId=$userId');
            await FirebaseAuth.instance.signOut();
            debugPrint('[OTP FLOW] Signed out immediately after signIn');
          } catch (signInError) {
            debugPrint('[OTP FLOW] signIn FAILED: $signInError');
            throw Exception(
              'This email is already registered. Please log in instead.',
            );
          }
        } else {
          rethrow;
        }
      }

      debugPrint('[OTP FLOW] Creating pending user document...');
      await _userService.createPendingUserDocument(userId, email);
      debugPrint('[OTP FLOW] User document created.');

      debugPrint('[OTP FLOW] Calling generateOTP API...');
      await _otpService.generateOTP(userId, email);
      debugPrint('[OTP FLOW] generateOTP API call completed.');

      if (!mounted) return;
      widget.onEmailSubmitted(email, userId);
    } catch (e) {
      debugPrint('[OTP FLOW] ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: widget.key,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 22),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: _Tokens.fieldInput,
              decoration: _pillDecoration(
                label: 'Email Address',
                hint: 'marcelito69@gmail.com',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/icons/email.png',
                    width: 14,
                    height: 14,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 10),
            Text(
              'We\'ll verify this address before your account is created.',
              style: _Tokens.poppins.copyWith(
                fontSize: 12,
                color: _Tokens.mutedWhite.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            _PrimaryButton(
              label: 'Send OTP Code',
              isLoading: _isLoading,
              onTap: _isLoading ? null : _onSubmit,
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: RichText(
                  text: TextSpan(
                    style: _Tokens.poppins.copyWith(
                      fontSize: 14,
                      color: _Tokens.mutedWhite,
                    ),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
                        style: TextStyle(
                          color: _Tokens.pink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Email Verification Code ─────────────────────────────────────────

class _Step2Otp extends StatefulWidget {
  final String email;
  final String userId;
  final bool otpSent;
  final VoidCallback onVerified;
  final VoidCallback onOtpSent;

  const _Step2Otp({
    super.key,
    required this.email,
    required this.userId,
    required this.otpSent,
    required this.onVerified,
    required this.onOtpSent,
  });

  @override
  State<_Step2Otp> createState() => _Step2OtpState();
}

class _Step2OtpState extends State<_Step2Otp> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 300; // 5 minutes
  Timer? _timer;

  final _otpService = OtpService();

  @override
  void initState() {
    super.initState();
    if (widget.otpSent) {
      _startResendTimer();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 300;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  String get _formattedCountdown {
    final m = _resendCountdown ~/ 60;
    final s = _resendCountdown % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _onVerify() async {
    final code = _enteredCode;
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _otpService.verifyOTP(widget.userId, code);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified successfully!')),
      );

      widget.onVerified();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onResend() async {
    if (!_canResend) return;

    try {
      await _otpService.generateOTP(widget.userId, widget.email, resend: true);
      widget.onOtpSent();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('New code sent!')));
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: widget.key,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            widget.email,
            style: _Tokens.poppins.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _Tokens.pink,
            ),
          ),
          const SizedBox(height: 20),

          // OTP Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 48,
                height: 56,
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.backspace &&
                        _controllers[index].text.isEmpty &&
                        index > 0) {
                      _controllers[index - 1].clear();
                      _focusNodes[index - 1].requestFocus();
                    }
                  },
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: _Tokens.poppins.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _Tokens.pink,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: _Tokens.fieldFill,
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                          color: _Tokens.fieldBorder,
                          width: 1,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: _Tokens.pink, width: 1.5),
                      ),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _focusNodes[index + 1].requestFocus();
                      }
                      if (value.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                      if (_enteredCode.length == 6) {
                        _onVerify();
                      }
                    },
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Helper row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Resend
              Flexible(
                child: _canResend || !widget.otpSent
                    ? GestureDetector(
                        onTap: _onResend,
                        child: Text.rich(
                          TextSpan(
                            style: _Tokens.poppins.copyWith(
                              fontSize: 12,
                              color: _Tokens.mutedWhite.withOpacity(0.7),
                            ),
                            children: [
                              const TextSpan(text: "Didn't get it? "),
                              TextSpan(
                                text: 'Resend Code',
                                style: TextStyle(
                                  color: _Tokens.pink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Text(
                        "Didn't get it?",
                        style: _Tokens.poppins.copyWith(
                          fontSize: 12,
                          color: _Tokens.mutedWhite.withOpacity(0.5),
                        ),
                      ),
              ),

              // Countdown
              if (!_canResend && widget.otpSent)
                Text(
                  'Expires in $_formattedCountdown',
                  style: _Tokens.poppins.copyWith(
                    fontSize: 12,
                    color: _Tokens.mutedWhite.withOpacity(0.6),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 32),
          _PrimaryButton(
            label: 'Verify Email',
            isLoading: _isLoading,
            onTap: _isLoading ? null : _onVerify,
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Personal Information ────────────────────────────────────────────

class _Step3Profile extends StatefulWidget {
  final String email;
  final String userId;

  const _Step3Profile({super.key, required this.email, required this.userId});

  @override
  State<_Step3Profile> createState() => _Step3ProfileState();
}

class _Step3ProfileState extends State<_Step3Profile> {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;

  final _authService = AuthService();
  final _userService = UserService();
  final _locationService = LocationService();

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _birthDateCtrl.dispose();
    _ageCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _Tokens.pink,
              onPrimary: Colors.white,
              surface: _Tokens.darkBg,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _birthDateCtrl.text =
          '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
      final age =
          now.year -
          picked.year -
          (now.month < picked.month ||
                  (now.month == picked.month && now.day < picked.day)
              ? 1
              : 0);
      _ageCtrl.text = age.toString();
    }
  }

  Future<Position?> _requireLocation() async {
    var hasAsked = false;
    while (true) {
      if (!mounted) return null;

      final permission = await _locationService.checkPermission();
      final granted =
          permission == LocationPermission.always ||
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
              onPressed: () =>
                  Navigator.pop(dialogContext, _LocationDialogAction.retry),
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

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms of Service')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final position = await _requireLocation();

      final pass = _passCtrl.text;
      final username = _usernameCtrl.text.trim().toLowerCase();
      final fullName = _fullNameCtrl.text.trim();

      // Re-authenticate with temp password, then update to real password
      await _authService.signIn(widget.email, 'temp_placeholder_otp');
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final credential = EmailAuthProvider.credential(
          email: widget.email,
          password: 'temp_placeholder_otp',
        );
        await currentUser.reauthenticateWithCredential(credential);
        await currentUser.updatePassword(pass);
      }

      final user = UserEntity(
        userId: widget.userId,
        displayName: fullName.isNotEmpty ? fullName : username,
        username: username,
        email: widget.email,
        authProvider: 'email',
        isPremium: false,
        createdAt: DateTime.now(),
        isGuest: false,
        lastActiveAt: DateTime.now(),
        isEmailVerified: true,
      );

      await _userService.createUserDocument(user);

      if (position != null) {
        try {
          await _userService.updateLocationIfNeeded(
            widget.userId,
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
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: widget.key,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verified Email (read-only)
            Text('Verified Email Address', style: _Tokens.label),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: widget.email,
              readOnly: true,
              style: _Tokens.fieldInput.copyWith(
                color: _Tokens.mutedWhite.withOpacity(0.7),
              ),
              decoration: _pillDecoration(
                label: 'Verified Email Address',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent.shade400,
                    size: 18,
                  ),
                ),
              ),
            ),
            _Tokens.fieldGap,

            // Full Name
            Text('Full Name', style: _Tokens.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fullNameCtrl,
              style: _Tokens.fieldInput,
              textCapitalization: TextCapitalization.words,
              decoration: _pillDecoration(label: 'Full Name', hint: 'John Doe'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your name';
                return null;
              },
            ),
            _Tokens.fieldGap,

            // Username
            Text('Username', style: _Tokens.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameCtrl,
              style: _Tokens.fieldInput,
              decoration: _pillDecoration(
                label: 'Username',
                hint: 'johndoe',
                helperText: 'Letters, numbers, and periods/underscores only',
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Enter a username';
                if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(value)) {
                  return '3-20 chars, letters, numbers, . _';
                }
                return null;
              },
            ),
            _Tokens.fieldGap,

            // Birth Date + Age (side by side)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Birth Date', style: _Tokens.label),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickBirthDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _birthDateCtrl,
                            style: _Tokens.fieldInput,
                            decoration: _pillDecoration(
                              label: 'Birth Date',
                              hint: 'MM/DD/YYYY',
                              suffixIcon: const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  Icons.calendar_today,
                                  color: _Tokens.pink,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Age', style: _Tokens.label),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _ageCtrl,
                        readOnly: true,
                        style: _Tokens.fieldInput,
                        textAlign: TextAlign.center,
                        decoration: _pillDecoration(label: 'Age'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _Tokens.fieldGap,

            // Password
            Text('Password', style: _Tokens.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePassword,
              style: _Tokens.fieldInput,
              decoration: _pillDecoration(
                label: 'Password',
                hint: 'Enter your password',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/icons/password.png',
                    width: 14,
                    height: 14,
                  ),
                ),
                suffixIcon: GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      _obscurePassword
                          ? 'assets/icons/see.png'
                          : 'assets/icons/unsee.png',
                      width: 18,
                      height: 18,
                    ),
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter password';
                if (v.length < 6) return 'Password too short';
                return null;
              },
            ),
            _Tokens.fieldGap,

            // Confirm Password
            Text('Confirm Password', style: _Tokens.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: _obscureConfirm,
              style: _Tokens.fieldInput,
              decoration: _pillDecoration(
                label: 'Confirm Password',
                hint: 'Re-enter your password',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/icons/password.png',
                    width: 14,
                    height: 14,
                  ),
                ),
                suffixIcon: GestureDetector(
                  onTap: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      _obscureConfirm
                          ? 'assets/icons/see.png'
                          : 'assets/icons/unsee.png',
                      width: 18,
                      height: 18,
                    ),
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirm your password';
                if (v != _passCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Terms checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _agreedToTerms,
                    onChanged: (v) =>
                        setState(() => _agreedToTerms = v ?? false),
                    activeColor: _Tokens.pink,
                    checkColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: _Tokens.poppins.copyWith(
                        fontSize: 12,
                        color: _Tokens.mutedWhite.withOpacity(0.7),
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            color: _Tokens.pink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: _Tokens.pink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ', and acknowledge that my personal information will be handled securely and responsibly.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            _PrimaryButton(
              label: 'Create Account',
              isLoading: _isLoading,
              onTap: _isLoading ? null : _onSubmit,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

enum _LocationDialogAction { retry, openSettings }
