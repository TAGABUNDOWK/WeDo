import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:choosly/services/call/call_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 12, 0, 0);

  Map<String, dynamic> participant({
    String status = 'active',
    DateTime? lastSeen,
    bool withLastSeen = true,
  }) {
    return {
      'status': status,
      if (withLastSeen) 'lastSeen': Timestamp.fromDate(lastSeen ?? now),
    };
  }

  group('CallService.isLiveParticipant', () {
    test('active with a fresh heartbeat is live', () {
      expect(
        CallService.isLiveParticipant(
          participant(lastSeen: now.subtract(const Duration(seconds: 20))),
          now: now,
        ),
        isTrue,
      );
    });

    test('active with a stale heartbeat is not live', () {
      expect(
        CallService.isLiveParticipant(
          participant(lastSeen: now.subtract(const Duration(seconds: 91))),
          now: now,
        ),
        isFalse,
      );
    });

    test('heartbeat exactly on the 90s boundary is still live', () {
      expect(
        CallService.isLiveParticipant(
          participant(lastSeen: now.subtract(const Duration(seconds: 90))),
          now: now,
        ),
        isTrue,
      );
    });

    test('a participant without lastSeen falls back to status only', () {
      // Docs written by app versions that predate the heartbeat must not be
      // treated as dead - otherwise a mixed fleet ends live calls.
      expect(
        CallService.isLiveParticipant(
          participant(withLastSeen: false),
          now: now,
        ),
        isTrue,
      );
      expect(
        CallService.isLiveParticipant(
          participant(status: 'left', withLastSeen: false),
          now: now,
        ),
        isFalse,
      );
    });

    test('a left participant is never live, heartbeat or not', () {
      expect(
        CallService.isLiveParticipant(
          participant(status: 'left'),
          now: now,
        ),
        isFalse,
      );
    });

    test('modest client clock skew ahead of the server stays live', () {
      expect(
        CallService.isLiveParticipant(
          participant(lastSeen: now.add(const Duration(seconds: 30))),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
