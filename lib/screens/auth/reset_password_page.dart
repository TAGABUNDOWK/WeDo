import 'package:flutter/material.dart';
import '../../services/auth/otp_service.dart';
import '../../widgets/animated_background.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String code;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _otpService = OtpService();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isLoading = false;
  bool _showNewPassword = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  int? _selectedOption;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _selectOption(int option) {
    setState(() {
      _selectedOption = option;
      if (option != 1) {
        _showNewPassword = false;
      }
    });
  }

  Future<void> _onUpdatePassword() async {
    if (_newPassCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters')),
      );
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _otpService.resetPassword(
        widget.email,
        widget.code,
        _newPassCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully!')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onKeepCurrent() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You can now log in with your current password.'),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
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

  Widget _optionCard({
    required int option,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedOption == option;
    return GestureDetector(
      onTap: () {
        _selectOption(option);
        if (option == 1) {
          setState(() {
            _showNewPassword = true;
            _selectedOption = option;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFE4EF0).withValues(alpha: 0.15)
              : const Color(0xFF211635),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFFFE4EF0)
                : Colors.white.withValues(alpha: 0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFFE4EF0), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? const Color(0xFFFE4EF0)
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
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
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.4),
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
              : child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0A2E).withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                const Text(
                  'RESET PASSWORD',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFE4EF0),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose Your Option',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your email has been confirmed. Choose how you want to proceed.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                _optionCard(
                  option: 1,
                  icon: Icons.edit,
                  title: 'Set a New Password',
                  subtitle: 'Create a new password for your account',
                ),
                const SizedBox(height: 14),
                _optionCard(
                  option: 2,
                  icon: Icons.lock,
                  title: 'Keep Current Password',
                  subtitle: 'Continue using your existing password',
                ),

                if (_showNewPassword) ...[
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _newPassCtrl,
                    obscureText: _obscureNew,
                    style: const TextStyle(color: Colors.white),
                    decoration: _pillInputDecoration(
                      label: 'New Password',
                      hint: 'Enter new password',
                      prefixIcon: _newPassCtrl.text.isEmpty
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
                              _obscureNew = !_obscureNew;
                            });
                          },
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Center(
                              child: Image.asset(
                                _obscureNew
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
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscureConfirm,
                    style: const TextStyle(color: Colors.white),
                    decoration: _pillInputDecoration(
                      label: 'Confirm Password',
                      hint: 'Re-enter new password',
                      prefixIcon: _confirmPassCtrl.text.isEmpty
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
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Center(
                              child: Image.asset(
                                _obscureConfirm
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
                  ),
                ],

                const SizedBox(height: 28),

                if (_selectedOption == 1 && _showNewPassword)
                  _gradientButton(
                    onTap: _onUpdatePassword,
                    child: const Text(
                      'Update Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (_selectedOption == 2)
                  _gradientButton(
                    onTap: _onKeepCurrent,
                    child: const Text(
                      'Continue to Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}