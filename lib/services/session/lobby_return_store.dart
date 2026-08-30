import 'package:flutter/foundation.dart';

/// Global in-memory store for a host's temporarily-parked PickFight lobby.
///
/// When a host chooses to leave the lobby to browse the app (without
/// cancelling the session), the lobby's sessionId is parked here so a global
/// floating "Return to Lobby" button can be shown and can re-open the lobby.
///
/// Only one session can be parked at a time (a host can only host one session).
class LobbyReturnStore {
  LobbyReturnStore._();

  static final instance = LobbyReturnStore._();

  final ValueNotifier<String?> _parked = ValueNotifier<String?>(null);

  /// The sessionId currently parked, or null when there is no parked lobby.
  ValueNotifier<String?> get parked => _parked;

  /// Parks a lobby so a return button can be shown.
  void park({required String sessionId}) => _parked.value = sessionId;

  /// Clears the parked lobby (returned, cancelled, or started).
  void clear() => _parked.value = null;
}
