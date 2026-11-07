/// O módulo de tarefas. O host vê a função de registro, a lista de rotas
/// e os nomes delas (capítulo 34) e as traduções (capítulo 37); nada mais.
library;

import 'package:core/core.dart';
import 'package:get_it/get_it.dart';

import 'adapters/driven/services/rest_task_service.dart';
import 'adapters/driven/services/sqlite_task_service.dart';
import 'adapters/driven/services/task_local_service.dart';
import 'adapters/driven/sync/task_syncable_outbox.dart';
import 'adapters/driven/task_clearable_on_logout.dart';
import 'adapters/driven/task_repository_impl.dart';
import 'adapters/driven/uuid_v4.dart';
import 'adapters/driving/bloc/task_conflicts_bloc.dart';
import 'adapters/driving/bloc/task_edit_bloc.dart';
import 'adapters/driving/bloc/task_list_bloc.dart';
import 'application/ports/task_repository.dart';
import 'application/use_cases/task_use_case.dart';

export 'adapters/driving/l10n/tasks_module_localizations.dart'
    show TasksModuleLocalizations;
export 'adapters/driving/routes/tasks_module_routes.dart'
    show TaskRoutes, tasksModuleRoutes;

/// Registra o módulo no escopo da sessão, que o host abre no boot e renova
/// a cada fim de sessão (capítulo 32): nada daqui sobrevive à sessão
/// seguinte. Só esta função conhece as classes concretas, e nada é aberto
/// aqui: o banco abre no primeiro uso.
void registerTasksModuleDependencies(GetIt getIt) {
  DateTime now() => DateTime.now().toUtc();
  final local = SqliteTaskService(
    databaseFactory: getIt<LocalDatabaseFactory>(),
    newOperationId: () => newUuidV4(),
    now: now,
  );
  final outbox = TaskSyncableOutbox(
    apiClient: getIt<ApiClient>(),
    queue: local,
    conflicts: local,
    logger: getIt<AppLogger>(),
  );
  getIt
    ..registerSingleton<TaskLocalService>(
      local,
      dispose: (_) => local.dispose(),
    )
    ..registerLazySingleton<TaskRepository>(
      () => TaskRepositoryImpl(
        remote: RestTaskService(apiClient: getIt<ApiClient>()),
        local: getIt<TaskLocalService>(),
        outbox: outbox,
        logger: getIt<AppLogger>(),
        now: now,
      ),
    )
    ..registerLazySingleton<TaskUseCase>(
      () => TaskUseCase(
        repository: getIt<TaskRepository>(),
        newId: () => newUuidV4(),
        now: now,
        analytics: getIt<AppAnalytics>(),
      ),
    )
    // Fábricas: cada abertura de tela recebe um Bloc novo, que o
    // BlocProvider da Page fecha quando a tela sai da árvore.
    ..registerFactory<TaskListBloc>(
      () => TaskListBloc(tasks: getIt<TaskUseCase>()),
    )
    ..registerFactory<TaskEditBloc>(
      () => TaskEditBloc(tasks: getIt<TaskUseCase>()),
    )
    ..registerFactory<TaskConflictsBloc>(
      () => TaskConflictsBloc(tasks: getIt<TaskUseCase>()),
    );
  // Os registries são do escopo base; o fim do escopo da sessão os
  // esvazia. A fila inscrita é a mesma que o repositório aciona.
  getIt<LogoutCleanerRegistry>().register(TaskClearableOnLogout(local));
  getIt<OutboxRegistry>().register(outbox);
}
