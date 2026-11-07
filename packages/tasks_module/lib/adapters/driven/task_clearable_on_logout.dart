import 'package:core/core.dart';

import 'services/task_local_service.dart';

/// O que o módulo apaga no logout: as tarefas e as preferências do
/// usuário. Inscrito no `LogoutCleanerRegistry` pela função de registro do
/// módulo; o auth_module não sabe que ele existe (capítulo 29).
final class TaskClearableOnLogout implements ClearableOnLogout {
  TaskClearableOnLogout(this._local);

  final TaskLocalService _local;

  @override
  Future<void> clearLocalData() => _local.deleteAll();
}
