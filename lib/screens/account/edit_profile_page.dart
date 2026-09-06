import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_entity.dart';
import '../../services/auth/user_service.dart';

const _font = 'PlusJakartaSans';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _userService = UserService();
  final _displayNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _saving = false;
  UserEntity? _user;
  String? _usernameError;

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await _userService.getUserDocument(_uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _displayNameCtrl.text = user?.displayName ?? '';
      _usernameCtrl.text = user?.username ?? '';
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _usernameCtrl.text.trim().toLowerCase();
    final newDisplayName = _displayNameCtrl.text.trim();

    if (newUsername.isNotEmpty && newUsername != _user?.username) {
      final taken = await _userService.isUsernameTaken(newUsername, excludeUid: _uid);
      if (taken) {
        setState(() => _usernameError = 'Username already taken');
        return;
      }
    }

    setState(() {
      _saving = true;
      _usernameError = null;
    });

    try {
      await _userService.updateUserProfile(
        _uid,
        username: newUsername,
        displayName: newDisplayName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'Edit Profile',
          style: TextStyle(
            fontFamily: _font,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFE4EF0)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    // Display Name
                    const Text(
                      'Display Name',
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _displayNameCtrl,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0x991A0A2E),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 24, vertical: 18),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Color(0x4DFE4EF0),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Color(0xFFFE4EF0),
                            width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 1,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your display name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Username
                    const Text(
                      'Username',
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameCtrl,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0x991A0A2E),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 18),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Color(0x4DFE4EF0),
                            width: 1,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Color(0xFFFE4EF0),
                            width: 1.5,
                          ),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 1,
                          ),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                        helperText: 'Letters, numbers, and periods/underscores only',
                        helperStyle: TextStyle(
                          fontFamily: _font,
                          fontSize: 12,
                          color: const Color(0xFFFE4EF0).withValues(alpha: 0.8),
                        ),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter a username';
                        if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(value)) {
                          return '3-20 chars, letters, numbers, . _';
                        }
                        if (_usernameError != null) return _usernameError;
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: GestureDetector(
                        onTap: _saving ? null : _save,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: _saving
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
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: (_saving ? Colors.grey : const Color(0xFFFE4EF0))
                                    .withValues(alpha: 0.4),
                                offset: const Offset(0, 4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontFamily: _font,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
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
