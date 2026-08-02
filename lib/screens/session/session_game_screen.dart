import 'package:flutter/material.dart';
import '../../models/topic_entity.dart';
import '../../services/session/session_service.dart';

class SessionGameScreen extends StatefulWidget {
  final String topicId;
  final String topicTitle;

  const SessionGameScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  State<SessionGameScreen> createState() => _SessionGameScreenState();
}

class _SessionGameScreenState extends State<SessionGameScreen> {
  final _service = SessionService();
  final _bg = const Color(0xFFE7ECEF);

  List<CardEntity> _selectedCards = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final allCards = await _service.getCards(widget.topicId);
      final picked = _service.pickRandomCards(allCards);
      if (!mounted) return;
      setState(() {
        _selectedCards = picked;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          widget.topicTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadCards();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _selectedCards.isEmpty
                  ? const Center(
                      child: Text(
                        'No cards available for this topic',
                        style: TextStyle(color: Colors.black45),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _selectedCards.length,
                      itemBuilder: (context, index) {
                        final card = _selectedCards[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _bg,
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
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  card.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
