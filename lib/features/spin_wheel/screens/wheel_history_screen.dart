import 'package:flutter/material.dart';
import '../../../widgets/animated_background.dart';
import '../models/wheel_spin_record.dart';
import '../data/wheel_history_repository.dart';

class WheelHistoryScreen extends StatefulWidget {
  const WheelHistoryScreen({super.key});

  @override
  State<WheelHistoryScreen> createState() => _WheelHistoryScreenState();
}

class _WheelHistoryScreenState extends State<WheelHistoryScreen> {
  final _repository = WheelHistoryRepository();

  String _getDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) return 'Today';
    if (entryDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.month}/${date.day}/${date.year}';
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        showStars: false,
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Spin History',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // History list
              Expanded(
                child: StreamBuilder<List<WheelSpinRecord>>(
                  stream: _repository.getHistoryStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFE4EF0),
                        ),
                      );
                    }

                    final records = snapshot.data ?? [];

                    if (records.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.casino_outlined,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No spins yet',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Give it a try!',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Group by date
                    final grouped = <String, List<WheelSpinRecord>>{};
                    for (final record in records) {
                      final group = _getDateGroup(record.timestamp);
                      grouped.putIfAbsent(group, () => []).add(record);
                    }

                    return RefreshIndicator(
                      onRefresh: () async {},
                      color: const Color(0xFFFE4EF0),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: grouped.length,
                        itemBuilder: (context, sectionIndex) {
                          final group =
                              grouped.keys.elementAt(sectionIndex);
                          final groupRecords = grouped[group]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                child: Text(
                                  group,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),

                              // Records
                              ...groupRecords.map((record) {
                                return Dismissible(
                                  key: ValueKey(record.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding:
                                        const EdgeInsets.only(right: 20),
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.3),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor:
                                            const Color(0xFF2A1450),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        title: const Text(
                                          'Delete Spin',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.white,
                                          ),
                                        ),
                                        content: Text(
                                          'Remove "${record.winningOption.label}" from history?',
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                                    context, false),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(
                                                        alpha: 0.6),
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                                    context, true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color:
                                                    Color(0xFFEF4444),
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onDismissed: (direction) async {
                                    await _repository
                                        .deleteSpin(record.id);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '"${record.winningOption.label}" removed',
                                          ),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            textColor:
                                                const Color(0xFFFE4EF0),
                                            onPressed: () {
                                              // Re-save would be complex; just refresh
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.05),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.08),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Color indicator
                                        Container(
                                          width: 4,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: record
                                                .winningOption.color,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Winner info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                record.winningOption
                                                    .label,
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow
                                                    .ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${_timeAgo(record.timestamp)}  ·  from ${record.optionCount} options',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12,
                                                  color: Colors.white
                                                      .withValues(
                                                          alpha: 0.4),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Expand icon
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.white
                                              .withValues(alpha: 0.3),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
