import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/constants.dart';
import '../../widgets/message_bubble.dart';
import 'message_search_screen.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatTime(dynamic timestamp) {
  if (timestamp == null) return '';
  DateTime dt;
  if (timestamp is Timestamp) {
    dt = timestamp.toDate();
  } else if (timestamp is DateTime) {
    dt = timestamp;
  } else {
    return '';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDate = DateTime(dt.year, dt.month, dt.day);
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final min = dt.minute.toString().padLeft(2, '0');
  final time = '$hour:$min $ampm';
  if (msgDate == today) return time;
  if (dt.year == now.year) return '${_months[dt.month - 1]} ${dt.day}';
  return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  String _groupName = '';

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection(AppConstants.groupsCollection)
        .doc(widget.groupId)
        .get();
    if (doc.exists && mounted) {
      setState(() => _groupName = doc.data()?['name'] ?? 'Group');
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    final senderName = _currentUser!.displayName ?? _currentUser!.email ?? 'Unknown';

    FirebaseFirestore.instance
        .collection(AppConstants.groupsCollection)
        .doc(widget.groupId)
        .collection(AppConstants.groupMessagesSubcollection)
        .add({
      'senderId': _currentUser!.uid,
      'senderName': senderName,
      'type': 'text',
      'content': text,
      'reactions': {},
      'readBy': [_currentUser!.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    FirebaseFirestore.instance
        .collection(AppConstants.groupsCollection)
        .doc(widget.groupId)
        .update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    _messageCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final messageId = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => MessageSearchScreen(groupId: widget.groupId),
                ),
              );
              if (messageId != null && _scrollCtrl.hasClients) {
                // Find the message index and scroll to it
                final snapshot = await FirebaseFirestore.instance
                    .collection(AppConstants.groupsCollection)
                    .doc(widget.groupId)
                    .collection(AppConstants.groupMessagesSubcollection)
                    .orderBy('createdAt', descending: false)
                    .get();
                final index = snapshot.docs.indexWhere((doc) => doc.id == messageId);
                if (index != -1 && _scrollCtrl.hasClients) {
                  _scrollCtrl.animateTo(
                    index * 80.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.pushNamed(context, '/group-info', arguments: widget.groupId);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.groupsCollection)
                  .doc(widget.groupId)
                  .collection(AppConstants.groupMessagesSubcollection)
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final senderId = data['senderId'] as String? ?? '';
                    final isMe = senderId == _currentUser?.uid;

                    final ts = data['createdAt'] as Timestamp?;
                    final localTs = data['createdAtLocal'] as String?;
                    final displayTime = ts != null
                        ? _formatTime(ts)
                        : (localTs != null ? _formatTime(DateTime.parse(localTs)) : '');

                    final type = data['type'] as String? ?? 'text';
                    final content = data['content'] as String? ?? '';
                    final imageUrl = data['imageUrl'] as String?;

                    if (type == 'image' && imageUrl != null) {
                      return MessageBubble(
                        content: content,
                        imageUrl: imageUrl,
                        isMe: isMe,
                        senderName: isMe ? null : data['senderName'],
                        time: displayTime,
                      );
                    }

                    return MessageBubble(
                      content: content,
                      isMe: isMe,
                      senderName: isMe ? null : data['senderName'],
                      time: displayTime,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: () {
                      // TODO: image_picker
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
