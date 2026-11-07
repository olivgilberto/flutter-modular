import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/bootstrap/boot.dart';
import 'package:mobile_tarefas_app/bootstrap/dependency_injection.dart';

import '../support/fakes.dart';

void main() {
  late FakeLogger logger;
  late FakePreferences preferences;

  setUp(() {
    logger = FakeLogger();
    preferences = FakePreferences(storedLanguage: 'pt-BR');
  });
  // O boot espera por tudo o que está no get_it global; cada teste começa
  // de um get_it vazio, sem o que o teste anterior deixou pendente.
  tearDown(getIt.reset);

  /// O composition root do teste: só as duas portas que o boot usa.
  void configure() => getIt
    ..registerSingleton<AppLogger>(logger)
    ..registerSingleton<AppPreferences>(preferences);

  Future<void> noop() async {}

  test('sem o Firebase, o boot termina e registra o motivo', () async {
    final settings = await boot(
      initializeFirebase: () => Future.error(Exception('sem configuração')),
      installErrorHandlers: () {},
      configure: configure,
      scheduleSync: noop,
      timeout: const Duration(milliseconds: 50),
    );
    addTearDown(settings.dispose);

    expect(settings.locale, const Locale('pt', 'BR'));
    expect(logger.logs, ['boot: Firebase indisponível (_Exception)']);
  });

  test('um Firebase que não responde cai no tempo limite', () async {
    final settings = await boot(
      initializeFirebase: () => Completer<void>().future,
      installErrorHandlers: () {},
      configure: configure,
      scheduleSync: noop,
      timeout: const Duration(milliseconds: 50),
    );
    addTearDown(settings.dispose);

    expect(logger.logs.single, startsWith('boot: Firebase indisponível'));
  });

  test('os passos rodam em ordem: handlers antes da injeção', () async {
    final steps = <String>[];

    final settings = await boot(
      initializeFirebase: () async => steps.add('firebase'),
      installErrorHandlers: () => steps.add('handlers'),
      configure: () {
        steps.add('injeção');
        configure();
      },
      scheduleSync: () async => steps.add('agendamento'),
    );
    addTearDown(settings.dispose);

    expect(steps, ['firebase', 'handlers', 'injeção', 'agendamento']);
    expect(logger.logs, isEmpty);
  });

  test('um serviço assíncrono que não fica pronto não trava o boot', () async {
    final settings = await boot(
      initializeFirebase: noop,
      installErrorHandlers: () {},
      configure: () {
        configure();
        getIt.registerSingletonAsync<_SlowService>(
          () => Completer<_SlowService>().future,
        );
      },
      scheduleSync: noop,
      timeout: const Duration(milliseconds: 50),
    );
    addTearDown(settings.dispose);

    // O get_it lista cada pendente como "nomeDaInstância : Tipo".
    expect(logger.logs, ['boot: serviços não prontos: [null : _SlowService]']);
  });

  test('um agendamento que falha ou não responde não impede o app de '
      'abrir, e vai ao registro de falhas', () async {
    for (final schedule in [
      () => Future<void>.error(Exception('workmanager ausente')),
      () => Completer<void>().future,
    ]) {
      logger.errors.clear();
      final settings = await boot(
        initializeFirebase: noop,
        installErrorHandlers: () {},
        configure: configure,
        scheduleSync: schedule,
        timeout: const Duration(milliseconds: 50),
      );
      settings.dispose();
      await getIt.reset();

      expect(logger.errors, ['boot sync schedule']);
    }
  });
}

/// Um serviço cuja inicialização nunca termina.
final class _SlowService {}
