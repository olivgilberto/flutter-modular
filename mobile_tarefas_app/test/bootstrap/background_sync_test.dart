import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/bootstrap/background_sync.dart';
import 'package:mobile_tarefas_app/bootstrap/dependency_injection.dart';

import '../support/fakes.dart';

/// A sessão guardada, como o auth_module a entrega ao core.
final class _FakeTokenProvider implements TokenProvider {
  _FakeTokenProvider(this.token);

  String? token;
  Object? failure;

  @override
  Future<String?> currentToken() async {
    if (failure case final Object error) throw error;
    return token;
  }

  @override
  Future<String?> refreshToken() async => null;
}

/// A fila de um módulo: conta quantas vezes foi enviada e diz se algo
/// ficou para depois.
final class _FakeOutbox implements SyncableOutbox {
  var syncs = 0;
  var somethingLeft = false;

  @override
  String get name => 'tasks';

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<bool> sync() async {
    syncs++;
    return somethingLeft;
  }
}

void main() {
  late FakeLogger logger;
  late _FakeTokenProvider tokens;
  late _FakeOutbox outbox;
  late List<String> steps;

  setUp(() {
    logger = FakeLogger();
    tokens = _FakeTokenProvider('at-1');
    outbox = _FakeOutbox();
    steps = [];
  });
  // O isolate de segundo plano começa com o get_it vazio; cada teste também.
  tearDown(getIt.reset);

  /// O composition root do teste: só o que a execução usa.
  void configure() {
    steps.add('injeção');
    final registry = DefaultOutboxRegistry();
    getIt
      ..registerSingleton<AppLogger>(logger)
      ..registerSingleton<TokenProvider>(tokens)
      ..registerSingleton<OutboxRegistry>(registry)
      ..registerSingleton<OutboxSyncWorker>(
        OutboxSyncWorker(registry: registry, logger: logger),
      );
  }

  /// O que o escopo da sessão faz: os módulos inscrevem suas filas, uma
  /// vez, porque o escopo só abre se ainda não estiver aberto.
  void openSession() {
    steps.add('escopo');
    final registry = getIt<OutboxRegistry>();
    if (registry.outboxes.isEmpty) registry.register(outbox);
  }

  Future<bool> run() => syncInBackground(
    configure: configure,
    initializeFirebase: () async => steps.add('firebase'),
    openSession: openSession,
  );

  test('com sessão guardada, abre o escopo e envia; sem nada para depois, '
      'a tarefa terminou bem', () async {
    expect(await run(), isTrue);

    expect(steps, ['firebase', 'injeção', 'escopo']);
    expect(outbox.syncs, 1);
  });

  test(
    'algo que ficou para depois pede ao sistema uma nova tentativa',
    () async {
      outbox.somethingLeft = true;

      expect(await run(), isFalse);
    },
  );

  test('sem sessão guardada, nada é enviado e a fila espera o login', () async {
    tokens.token = null;

    expect(await run(), isTrue);

    expect(steps, isNot(contains('escopo')));
    expect(outbox.syncs, 0);
  });

  test('a composição roda uma vez por isolate, mesmo com várias '
      'execuções', () async {
    await run();
    await run();

    expect(steps.where((step) => step == 'injeção'), hasLength(1));
    expect(outbox.syncs, 2);
  });

  test('sem o Firebase, a execução segue', () async {
    final result = await syncInBackground(
      configure: configure,
      initializeFirebase: () => Future.error(Exception('sem configuração')),
      openSession: openSession,
      timeout: const Duration(milliseconds: 50),
    );

    expect(result, isTrue);
    expect(outbox.syncs, 1);
  });

  test('um banco ilegível vai ao registro de falhas e pede nova '
      'tentativa', () async {
    tokens.failure = const LocalDatabaseError('banco travado');

    expect(await run(), isFalse);

    expect(logger.errors, ['background sync']);
  });
}
