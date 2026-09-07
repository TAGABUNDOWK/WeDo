import 'dart:async';

class TriRaceRefreshNotifier {
  static final instance = TriRaceRefreshNotifier._();
  TriRaceRefreshNotifier._();

  final _controller = StreamController<void>.broadcast();
  Stream<void> get onRefresh => _controller.stream;
  void notifyRefresh() => _controller.add(null);
  void dispose() => _controller.close();
}
