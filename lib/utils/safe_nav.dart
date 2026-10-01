import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs [action] on the next microtask, outside of any build pass, and logs
/// rather than propagates anything it throws.
///
/// Navigation must never run synchronously from `initState`, `build`,
/// `didChangeDependencies`, `didUpdateWidget`, or anything they call
/// synchronously. Flutter's `Navigator` performs all of its bookkeeping in
/// `_flushHistoryUpdates()` while holding a private debug lock:
///
/// ```dart
/// void _pushEntry(_RouteEntry entry) {
///   assert(!_debugLocked);
///   assert(() { _debugLocked = true; return true; }());
///   ...
///   _flushHistoryUpdates();          // <- throws while locked
///   assert(() { _debugLocked = false; return true; }());
/// }
/// ```
///
/// There is no `try/finally`. If anything throws while the lock is held -
/// most commonly `markNeedsBuild() called during build`, raised by the
/// overlay when it is rearranged from inside a build pass - the lock is never
/// released, and every later navigation in the app dies with
/// `assert(!_debugLocked)`.
///
/// Deferring to a microtask guarantees the action runs after the current
/// synchronous frame work unwinds, so `owner.debugBuilding` is false by then.
/// It also always runs, unlike a `SchedulerBinding.addPostFrameCallback`,
/// which silently waits for a frame that may never be scheduled.
///
/// [action] is responsible for its own `mounted` checks: the caller's widget
/// may legitimately have been disposed before the microtask runs.
///
/// [action] may be `async`. It is awaited inside the guard so that a rejected
/// future - how an `async` function reports an error - is logged here rather
/// than escaping as an unhandled async error.
void safeNav(FutureOr<void> Function() action, {String label = 'nav'}) {
  scheduleMicrotask(() async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('$label failed: $error');
      debugPrintStack(label: label, stackTrace: stackTrace);
    }
  });
}
