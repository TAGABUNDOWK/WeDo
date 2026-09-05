import 'package:flutter/foundation.dart';

/// Global in-memory store for a temporarily-parked PickFight lobby.
///
/// When a host or participant chooses to leave the lobby to browse the app
/// (without cancelling or leaving the session), the lobby's sessionId is
/// parked here so a global floating "Return to Lobby" button can be shown
/// and can re-open the lobby.
///
/// Only one session can be parked at a time.
class LobbyReturnStore {
  LobbyReturnStore._();

  static final instance = LobbyReturnStore._();

  final ValueNotifier<String?> _parked = ValueNotifier<String?>(null);
  bool _isHost = false;

  /// The sessionId currently parked, or null when there is no parked lobby.
  ValueNotifier<String?> get parked => _parked;

  /// Whether the parked session belongs to the host.
  bool get isHost => _isHost;

  /// Parks a lobby so a return button can be shown.
  void park({required String sessionId, required bool isHost}) {
    _isHost = isHost;
    _parked.value = sessionId;
  }

  /// Clears the parked lobby (returned, cancelled, or started).
  void clear() {
    _isHost = false;
    _parked.value = null;
  }
}
