import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/user_service.dart';
import '../../widgets/animated_background.dart';
import 'create_account_page.dart';
import 'otp_verification_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _keepSignedIn = false;

  final _authService = AuthService();
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() {
      setState(() {});
    });
    _passCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;

      final credential = await _authService.signIn(email, pass);
      final userId = credential.user!.uid;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _userService.updateFcmToken(userId, token);
      }

      final isVerified = await _userService.isEmailVerified(userId);

      if (!mounted) return;

      if (!isVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationPage(userId: userId, email: email),
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _pillInputDecoration({
    required String label,
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF1A0A2E).withValues(alpha: 0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFE4EF0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: Stack(
          children: [
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
              child: Transform.translate(
                offset: const Offset(0, -40),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 0,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 0),

                          // Logo Section
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/WeDo-Logo.png',
                                  height: 140,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 8),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFFFE4EF0),
                                          Color(0xFF800DD8),
                                        ],
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
                          const SizedBox(height: 15),

                          // Text Block
                          const Text(
                            'GET STARTED',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFE4EF0),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 0),
                          const Text(
                            'Sign in account',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 0),
                          Text(
                            'Sign in with your registered email and password to proceed.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Email Address Field
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: _pillInputDecoration(
                              label: 'Email Address',
                              hint: 'marcelito69@gmail.com',
                              prefixIcon: _emailCtrl.text.isEmpty
                                  ? Transform.translate(
                                      offset: const Offset(8, 0),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Image.asset(
                                          'assets/icons/email.png',
                                          width: 12,
                                          height: 12,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter email';
                              if (!v.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Password Field
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: _pillInputDecoration(
                              label: 'Password',
                              hint: 'Enter your password',
                              prefixIcon: _passCtrl.text.isEmpty
                                  ? Transform.translate(
                                      offset: const Offset(8, 0),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Image.asset(
                                          'assets/icons/password.png',
                                          width: 12,
                                          height: 12,
                                        ),
                                      ),
                                    )
                                  : null,
                              suffixIcon: Transform.translate(
                                offset: const Offset(-8, 0),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Center(
                                      child: Image.asset(
                                        _obscurePassword
                                            ? 'assets/icons/see.png'
                                            : 'assets/icons/unsee.png',
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter password';
                              }
                              if (v.length < 6) return 'Password too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Options Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _keepSignedIn,
                                      onChanged: (value) {
                                        setState(() {
                                          _keepSignedIn = value ?? false;
                                        });
                                      },
                                      activeColor: const Color(0xFFFE4EF0),
                                      checkColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Keep me signed in',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Forget Password?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFFE4EF0),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          GestureDetector(
                            onTap: _isLoading ? null : _onSubmit,
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF800DD8),
                                    Color(0xFFFE4EF0),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFE4EF0,
                                    ).withValues(alpha: 0.4),
                                    offset: const Offset(0, 4),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Footer Text
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'New to WeDo? ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateAccountPage(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Create account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFFFE4EF0),
                                      fontWeight: FontWeight.w600,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
