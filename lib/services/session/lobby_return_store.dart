import 'package:flutter/foundation.dart';

enum LobbyType { session, triRace }

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
  LobbyType? _lobbyType;

  /// The sessionId currently parked, or null when there is no parked lobby.
  ValueNotifier<String?> get parked => _parked;

  /// Whether the parked session belongs to the host.
  bool get isHost => _isHost;

  /// The type of lobby parked (session or triRace).
  LobbyType? get lobbyType => _lobbyType;

  /// Parks a lobby so a return button can be shown.
  void park({
    required String sessionId,
    required bool isHost,
    required LobbyType lobbyType,
  }) {
    _isHost = isHost;
    _lobbyType = lobbyType;
    _parked.value = sessionId;
  }

  /// Clears the parked lobby (returned, cancelled, or started).
  void clear() {
    _isHost = false;
    _lobbyType = null;
    _parked.value = null;
  }
}
