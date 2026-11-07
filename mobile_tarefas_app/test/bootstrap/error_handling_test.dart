import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/bootstrap/dependency_injection.dart';
import 'package:mobile_tarefas_app/bootstrap/error_handling.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeLogger logger;

  // Os handlers são globais: cada teste guarda os originais e os devolve.
  late FlutterExceptionHandler? flutterOnError;
  late ErrorWidgetBuilder errorWidgetBuilder;

  setUp(() {
    flutterOnError = FlutterError.onError;
    errorWidgetBuilder = ErrorWidget.builder;
    logger = FakeLogger();
    getIt.pushNewScope(scopeName: 'test');
  });
  tearDown(() async {
    FlutterError.onError = flutterOnError;
    ErrorWidget.builder = errorWidgetBuilder;
    await getIt.popScopesTill('test');
  });

  test('um erro de build ou de layout vai para o AppLogger', () {
    getIt.registerSingleton<AppLogger>(logger);
    installGlobalErrorHandlers();

    FlutterError.onError!(FlutterErrorDetails(exception: StateError('bug')));

    expect(logger.fatals.single, isA<StateError>());
  });

  test('um erro assíncrono sem tratamento vai para o AppLogger e conta '
      'como tratado', () {
    getIt.registerSingleton<AppLogger>(logger);

    final handled = reportUncaughtError(StateError('bug'), StackTrace.current);

    expect(handled, isTrue);
    expect(logger.fatals.single, isA<StateError>());
  });

  test('antes da injeção, o erro não se perde nem derruba o handler', () {
    expect(
      () => reportUncaughtError(StateError('bug'), StackTrace.current),
      returnsNormally,
    );
  });

  test('um widget que falha vira o placeholder do design_system', () {
    installGlobalErrorHandlers();

    final widget = ErrorWidget.builder(
      FlutterErrorDetails(exception: StateError('bug')),
    );

    expect(widget, isA<AppErrorPlaceholder>());
  });
}
