import 'package:flutter/material.dart';
import '../../services/migration_service.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final _migrationService = MigrationService();
  bool _hasOldGroups = false;
  bool _isChecking = true;
  bool _isMigrating = false;
  MigrationResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkOldGroups();
  }

  Future<void> _checkOldGroups() async {
    final hasOld = await _migrationService.hasOldGroups();
    if (mounted) {
      setState(() {
        _hasOldGroups = hasOld;
        _isChecking = false;
      });
    }
  }

  Future<void> _runMigration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Run Migration?'),
        content: const Text(
          'This will move all data from the old "groups" collection '
          'to the new "group_chats" collection. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Migrate', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isMigrating = true;
      _error = null;
    });

    try {
      final result = await _migrationService.migrateGroupsToGroupChats();
      if (mounted) {
        setState(() {
          _result = result;
          _isMigrating = false;
          _hasOldGroups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isMigrating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database Migration')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: _isChecking
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasOldGroups ? Icons.warning_amber : Icons.check_circle,
                      size: 64,
                      color: _hasOldGroups ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _hasOldGroups
                          ? 'Old "groups" collection found'
                          : 'No old data to migrate',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasOldGroups
                          ? 'Tap the button below to migrate data to the new "group_chats" structure.'
                          : 'Your database is using the new structure.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    if (_isMigrating) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Migrating...'),
                    ] else if (_result != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _result.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ] else if (_hasOldGroups) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _runMigration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Migrate Data',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
