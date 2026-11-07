import 'package:auth_module/application/ports/data_owner_repository.dart';
import 'package:core/core.dart';

/// Registra só o que os testes do caso de uso conferem.
final class FakeLogger implements AppLogger {
  final userIds = <String?>[];
  final errors = <String>[];

  @override
  void setUserId(String? opaqueId) => userIds.add(opaqueId);

  @override
  void log(String message) {}

  @override
  void error(String reason, Object error, StackTrace stackTrace) =>
      errors.add(reason);

  @override
  void fatal(Object error, StackTrace stackTrace) {}
}

final class FakeAnalytics implements AppAnalytics {
  final events = <String>[];
  final parameters = <String, Map<String, Object>>{};

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const {},
  ]) async {
    events.add(name);
    this.parameters[name] = parameters;
  }

  @override
  Future<void> logScreenView(String screenName) async {}
}

/// O dono dos dados em memória. [failing] simula um banco que não pode ser
/// lido nem gravado.
final class FakeDataOwnerRepository implements DataOwnerRepository {
  String? owner;
  bool failing = false;

  void _check() {
    if (failing) throw const LocalDatabaseError('banco ilegível');
  }

  @override
  Future<String?> currentOwner() async {
    _check();
    return owner;
  }

  @override
  Future<void> saveOwner(String userId) async {
    _check();
    owner = userId;
  }

  @override
  Future<void> clearOwner() async {
    _check();
    owner = null;
  }
}
