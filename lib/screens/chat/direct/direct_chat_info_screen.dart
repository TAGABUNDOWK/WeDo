import 'package:flutter/material.dart';
import '../../../models/user_entity.dart';
import '../../../services/direct/direct_service.dart';
import '../../../services/theme/theme_service.dart';
import '../../../widgets/chat_theme_picker.dart';
import '../../../widgets/media_files_links_section.dart';
import '../search/direct_chat_search_screen.dart';

const _fontFamily = 'PlusJakartaSans';

class DirectChatInfoScreen extends StatefulWidget {
  final String chatId;
  final String otherUid;
  const DirectChatInfoScreen({super.key, required this.chatId, required this.otherUid});

  @override
  State<DirectChatInfoScreen> createState() => _DirectChatInfoScreenState();
}

class _DirectChatInfoScreenState extends State<DirectChatInfoScreen> {
  final _directService = DirectService();
  final _themeService = ThemeService();
  UserEntity? _otherUser;
  Map<String, String> _nicknames = {};
  bool _isLoading = true;
  bool _isMuted = false;
  String? _currentThemeId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _themeService.getChatThemeStream(widget.chatId, 'direct_chats').listen((id) {
      if (mounted) setState(() => _currentThemeId = id);
    });
  }

  Future<void> _loadData() async {
    final user = await _directService.getUser(widget.otherUid);
    final nicks = await _directService.getNicknames(widget.chatId);
    final muted = await _directService.isMuted(widget.chatId);
    if (mounted) {
      setState(() {
        _otherUser = user;
        _nicknames = nicks;
        _isMuted = muted;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMute() async {
    final uid = _directService.getCurrentUid();
    if (uid == null) return;
    await _directService.toggleMute(
      chatId: widget.chatId,
      uid: uid,
    );
    _loadData();
  }

  Future<void> _setTheme(String? themeId) async {
    if (themeId == null) {
      await _themeService.clearChatTheme(widget.chatId, 'direct_chats');
    } else {
      await _themeService.setChatTheme(widget.chatId, 'direct_chats', themeId);
    }
  }

  Future<void> _changeNickname() async {
    final currentUid = _directService.getCurrentUid();
    final currentNickname = currentUid != null ? _nicknames[currentUid] ?? '' : '';
    final ctrl = TextEditingController(text: currentNickname);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        ),
        title: const Text(
          'Change Nickname',
          style: TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontFamily: _fontFamily, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nickname for yourself',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: const Color(0xFF190831),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFE4EF0)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(fontFamily: _fontFamily, color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(fontFamily: _fontFamily, color: Color(0xFFFE4EF0), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result != null && currentUid != null && mounted) {
      await _directService.updateNickname(
        chatId: widget.chatId,
        uid: currentUid,
        nickname: result,
      );
      _loadData();
    }
  }

  Future<void> _changeOtherNickname() async {
    final otherNickname = _nicknames[widget.otherUid] ?? '';
    final ctrl = TextEditingController(text: otherNickname);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        ),
        title: const Text(
          'Change Nickname',
          style: TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontFamily: _fontFamily, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nickname for them',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: const Color(0xFF190831),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFE4EF0)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(fontFamily: _fontFamily, color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(fontFamily: _fontFamily, color: Color(0xFFFE4EF0), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await _directService.updateNickname(
        chatId: widget.chatId,
        uid: widget.otherUid,
        nickname: result,
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _otherUser?.displayName ?? widget.otherUid;
    final currentUid = _directService.getCurrentUid();
    final myNickname = currentUid != null ? _nicknames[currentUid] : null;
    final otherNickname = _nicknames[widget.otherUid];

    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      appBar: AppBar(
        backgroundColor: const Color(0xFF190831),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chat Info',
          style: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFE4EF0)))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                const SizedBox(height: 12),
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFFE4EF0).withValues(alpha: 0.2),
                    backgroundImage: _otherUser?.photoUrl != null && _otherUser!.photoUrl!.isNotEmpty
                        ? NetworkImage(_otherUser!.photoUrl!)
                        : null,
                    child: (_otherUser?.photoUrl == null || _otherUser!.photoUrl!.isEmpty)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 36, fontFamily: _fontFamily, color: Color(0xFFFE4EF0)),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_otherUser?.email != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _otherUser!.email!,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                _GlassCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _isMuted ? Icons.notifications_off : Icons.notifications,
                          color: _isMuted ? Colors.orangeAccent : const Color(0xFFFE4EF0),
                          size: 22,
                        ),
                        title: Text(
                          _isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                          style: const TextStyle(
                            fontFamily: _fontFamily,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Switch(
                          value: _isMuted,
                          onChanged: (_) => _toggleMute(),
                          activeColor: const Color(0xFFFE4EF0),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _GlassCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.search, color: Color(0xFF800DD8), size: 22),
                        title: const Text(
                          'Search in Conversation',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.4), size: 20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DirectChatSearchScreen(chatId: widget.chatId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chat Theme',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ChatThemePicker(
                        currentThemeId: _currentThemeId,
                        onSelected: _setTheme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined, color: Color(0xFF4ECDC4), size: 22),
                        title: const Text(
                          'Your Nickname',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          myNickname ?? 'Tap to set',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            color: myNickname != null ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.4), size: 20),
                        onTap: _changeNickname,
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_outline, color: const Color(0xFF4ECDC4).withValues(alpha: 0.7), size: 22),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontFamily: _fontFamily,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          otherNickname ?? 'Tap to set',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            color: otherNickname != null ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.4), size: 20),
                        onTap: _changeOtherNickname,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Media, Files & Links',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      MediaFilesLinksSection(chatId: widget.chatId),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
      ),
      child: child,
    );
  }
}
