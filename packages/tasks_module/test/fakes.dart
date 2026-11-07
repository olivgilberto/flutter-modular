import 'package:core/core.dart';

/// Anota só os erros registrados, que é o que os testes conferem.
final class FakeLogger implements AppLogger {
  final errors = <String>[];

  @override
  void setUserId(String? opaqueId) {}

  @override
  void log(String message) {}

  @override
  void error(String reason, Object error, StackTrace stackTrace) =>
      errors.add(reason);

  @override
  void fatal(Object error, StackTrace stackTrace) {}
}

/// Anota os eventos de produto na ordem em que chegam (capítulo 38).
final class FakeAnalytics implements AppAnalytics {
  final events = <(String, Map<String, Object>)>[];
  final screens = <String>[];

  List<String> get names => [for (final (name, _) in events) name];

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const {},
  ]) async => events.add((name, parameters));

  @override
  Future<void> logScreenView(String screenName) async =>
      screens.add(screenName);
}
