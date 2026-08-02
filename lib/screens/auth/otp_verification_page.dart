import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth/otp_service.dart';
import '../home/home_page.dart';

class OtpVerificationPage extends StatefulWidget {
  final String userId;
  final String email;

  const OtpVerificationPage({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _canResend = false;
  bool _sendingCode = true;
  bool _sendFailed = false;
  int _resendCountdown = 60;
  Timer? _timer;

  final _otpService = OtpService();

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
        setState(() => _canResend = true);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _sendingCode = true;
      _sendFailed = false;
    });

    try {
      await _otpService.generateOTP(widget.userId, widget.email);
      if (!mounted) return;
      setState(() => _sendingCode = false);
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _sendFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t send code: $e')),
      );
    }
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
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

  Future<void> _onResend() async {
    if (!_canResend) return;

    try {
      await _otpService.generateOTP(widget.userId, widget.email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New code sent!')),
      );
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
                    child: Icon(Icons.mark_email_unread_outlined, size: 60, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Verify Your Email', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
                ),
                if (_sendingCode) ...[
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Sending your verification code...'),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _neumorphicDecoration(color: bg),
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
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: const Color(0xFFE7ECEF),
                                  contentPadding: EdgeInsets.zero,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.blue, width: 2),
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
                                : const Text('Verify',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                        child: const Text('Resend Code'),
                      )
                    : _canResend
                        ? TextButton(
                            onPressed: _onResend,
                            child: const Text('Resend Code'),
                          )
                        : Text(
                            'Resend code in $_resendCountdown seconds',
                            style: const TextStyle(color: Colors.black54),
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
