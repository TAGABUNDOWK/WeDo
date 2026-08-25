import 'dart:async';

class SessionRefreshNotifier {
  static final instance = SessionRefreshNotifier._();
  SessionRefreshNotifier._();

  final _controller = StreamController<void>.broadcast();
  Stream<void> get onRefresh => _controller.stream;
  void notifyRefresh() => _controller.add(null);
  void dispose() => _controller.close();
}
