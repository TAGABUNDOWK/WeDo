import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth/otp_service.dart';

const _font = 'PlusJakartaSans';

class EmailChangeOtpScreen extends StatefulWidget {
  final String userId;
  final String newEmail;

  const EmailChangeOtpScreen({
    super.key,
    required this.userId,
    required this.newEmail,
  });

  @override
  State<EmailChangeOtpScreen> createState() => _EmailChangeOtpScreenState();
}

class _EmailChangeOtpScreenState extends State<EmailChangeOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _otpService = OtpService();
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  bool _isLoading = false;
  bool _canResend = false;
  bool _sendingCode = true;
  bool _sendFailed = false;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendCode();
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
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _sendingCode = true;
      _sendFailed = false;
    });

    try {
      await _otpService.generateOTP(widget.userId, widget.newEmail, purpose: 'email_change');
      if (!mounted) return;
      setState(() => _sendingCode = false);
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _sendFailed = true;
      });
      _showSnack('Couldn\'t send code: $e', bg: Colors.redAccent);
    }
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _showSnack(String message, {Color bg = const Color(0xFF800DD8)}) {
    if (!mounted) return;
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bg),
    );
  }

  Future<void> _onVerify() async {
    final code = _enteredCode;
    if (code.length != 6) {
      _showSnack('Please enter the full 6-digit code', bg: Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _otpService.verifyEmailChangeOTP(widget.userId, code, widget.newEmail);

      if (!mounted) return;

      _showSnack('Email updated successfully');

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), bg: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onResend() async {
    if (!_canResend) return;

    try {
      await _otpService.generateOTP(widget.userId, widget.newEmail, resend: true, purpose: 'email_change');

      if (!mounted) return;
      _showSnack('New code sent!');
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), bg: Colors.redAccent);
    }
  }

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
            'Verify Email Change',
            style: TextStyle(
              fontFamily: _font,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFE4EF0), Color(0xFF800DD8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Confirm Email Change',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: _font,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We sent a 6-digit code to',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: _font,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.newEmail,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFE4EF0),
                      fontFamily: _font,
                    ),
                  ),
                  if (_sendingCode) ...[
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFE4EF0),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Sending your verification code...',
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: _font,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 44,
                              height: 52,
                              child: KeyboardListener(
                                focusNode: FocusNode(),
                                onKeyEvent: (event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.backspace &&
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
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: _font,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: const Color(0x991A0A2E),
                                    contentPadding: EdgeInsets.zero,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0x4DFE4EF0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFFE4EF0),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
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
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: _isLoading || _sendingCode ? null : _onVerify,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: _isLoading || _sendingCode
                                  ? LinearGradient(
                                      colors: [
                                        Colors.grey.shade600,
                                        Colors.grey.shade500,
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF800DD8), Color(0xFFFE4EF0)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isLoading || _sendingCode
                                          ? Colors.grey
                                          : const Color(0xFFFE4EF0))
                                      .withValues(alpha: 0.4),
                                  offset: const Offset(0, 4),
                                  blurRadius: 12,
                                ),
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
                                  : const Text(
                                      'Verify',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: _font,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sendFailed
                      ? TextButton(
                          onPressed: _sendCode,
                          child: const Text(
                            'Resend Code',
                            style: TextStyle(
                              color: Color(0xFFFE4EF0),
                              fontFamily: _font,
                            ),
                          ),
                        )
                      : _canResend
                          ? TextButton(
                              onPressed: _onResend,
                              child: const Text(
                                'Resend Code',
                                style: TextStyle(
                                  color: Color(0xFFFE4EF0),
                                  fontFamily: _font,
                                ),
                              ),
                            )
                          : Text(
                              'Resend code in $_resendCountdown seconds',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontFamily: _font,
                              ),
                            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
