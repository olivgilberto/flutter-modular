import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';

import 'dependency_injection.dart';

/// Passo 3 do boot, depois do `WidgetsFlutterBinding.ensureInitialized()` e
/// antes da injeção de dependências, para cobrir também
/// as falhas da própria inicialização (capítulo 14). O usuário nunca vê uma
/// tela técnica nem o retângulo cinza do modo release.
void installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details); // continua no console em debug
    reportUncaughtError(details.exception, details.stack ?? StackTrace.current);
  };
  WidgetsBinding.instance.platformDispatcher.onError = reportUncaughtError;
  // Só visual e sem texto: pode ser construído sem localização.
  ErrorWidget.builder = (_) => const AppErrorPlaceholder();
}

/// O destino comum dos dois handlers. Público para os testes: no
/// flutter_test, o setter de `platformDispatcher.onError` não guarda o valor.
///
/// Os handlers nascem antes da injeção, então o AppLogger pode ainda não
/// existir.
@visibleForTesting
bool reportUncaughtError(Object error, StackTrace stack) {
  if (getIt.isRegistered<AppLogger>()) {
    getIt<AppLogger>().fatal(error, stack);
  } else {
    debugPrint('$error\n$stack');
  }
  return true; // tratado: não propaga
}
