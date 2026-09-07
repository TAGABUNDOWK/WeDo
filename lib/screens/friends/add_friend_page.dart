import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_entity.dart';
import '../../services/friends/friend_service.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _searchCtrl = TextEditingController();
  final _friendService = FriendService();
  final _auth = FirebaseAuth.instance;
  final _bg = const Color(0xFF190831);

  bool _isLoading = false;
  List<UserEntity> _results = [];
  Map<String, String> _partners = {};
  String _searchedQuery = '';

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPartners() async {
    final partners = await _friendService.getPartnerStatusMap(_uid);
    if (!mounted) return;
    setState(() => _partners = partners);
  }

  Future<void> _onSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final results = await _friendService.searchUsers(query, excludeUid: _uid);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searchedQuery = query;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSend(UserEntity user) async {
    try {
      await _friendService.sendRequest(_uid, user.userId);
      if (!mounted) return;
      setState(() => _partners[user.userId] = 'pending');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to @${user.username}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Widget _buildResult(UserEntity user) {
    final status = _partners[user.userId];
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            child: const Icon(Icons.person, color: Color(0xFFFE4EF0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'User' : name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.username.isNotEmpty && user.username != user.displayName)
                  Text(
                    '@${user.username}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (status == 'friends')
            const Text('Friends', style: TextStyle(color: Colors.green))
          else if (status == 'pending')
            const Text('Sent', style: TextStyle(color: Colors.white54))
          else
            TextButton(
              onPressed: () => _onSend(user),
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Add Friend',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _onSearch(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by username',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.35),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFE4EF0)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _onSearch,
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _searchedQuery.isEmpty
                                ? 'Search for a username to add friends'
                                : 'No user found with that username',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results.length,
                          itemBuilder: (context, index) =>
                              _buildResult(_results[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
