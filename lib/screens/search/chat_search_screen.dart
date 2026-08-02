import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../services/chat/chat_search_service.dart';
import '../../services/group/group_service.dart';
import '../../utils/time_format.dart';

class ChatSearchScreen extends StatefulWidget {
  final String groupId;
  const ChatSearchScreen({super.key, required this.groupId});

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _searchCtrl = TextEditingController();
  final _groupService = GroupService();
  final _searchService = ChatSearchService();
  String? _selectedSenderId;
  DateTime? _startDate;
  DateTime? _endDate;
  List<ChatMessage> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final memberData = await _groupService.getGroupMembersWithNames(widget.groupId);
    if (mounted) setState(() => _members = memberData);
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _searchService.searchGroupMessages(
        groupId: widget.groupId,
        senderId: _selectedSenderId,
        startDate: _startDate,
        endDate: _endDate,
        textQuery: _searchCtrl.text.trim(),
      );
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSenderId = null;
      _startDate = null;
      _endDate = null;
      _searchCtrl.clear();
      _results = [];
      _hasSearched = false;
    });
  }

  void _jumpToMessage(String messageId) {
    Navigator.pop(context, messageId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Messages'),
        actions: [
          if (_hasSearched)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search message content...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedSenderId,
                        hint: const Text('Any user'),
                        decoration: InputDecoration(
                          labelText: 'From',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Any user'),
                          ),
                          ..._members.map((m) => DropdownMenuItem<String?>(
                                value: m['uid'] as String,
                                child: Text(m['displayName'] as String),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSenderId = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: true),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _startDate != null ? formatMonthDay(_startDate!) : 'From date',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: false),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _endDate != null ? formatMonthDay(_endDate!) : 'To date',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isLoading ? null : _search,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
                if (_selectedSenderId != null || _startDate != null || _endDate != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (_selectedSenderId != null)
                        Chip(
                          label: Text(
                            _members.firstWhere(
                              (m) => m['uid'] == _selectedSenderId,
                              orElse: () => {'displayName': _selectedSenderId},
                            )['displayName'] as String,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: () => setState(() => _selectedSenderId = null),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (_startDate != null)
                        Chip(
                          label: Text(formatMonthDay(_startDate!), style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() => _startDate = null),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (_endDate != null)
                        Chip(
                          label: Text(formatMonthDay(_endDate!), style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() => _endDate = null),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _hasSearched
                ? _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No messages found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final msg = _results[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _jumpToMessage(msg.id),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              child: Text(
                                                msg.senderName.isNotEmpty
                                                    ? msg.senderName[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                msg.senderName,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                            ),
                                            Text(
                                              formatSearchDate(msg.createdAt),
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          msg.content,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.manage_search, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Search by content, user, or date', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
