import 'dart:async';

import 'package:auth_module/auth_module.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/session/session_gate.dart';

import '../support/fakes.dart';

void main() {
  late StreamController<SessionState> changes;
  late List<String> calls;

  setUp(() {
    changes = StreamController<SessionState>.broadcast();
    calls = [];
  });

  SessionGate gate({SessionState initial = const SessionUnknown()}) {
    final gate = SessionGate(
      initial: initial,
      changes: changes.stream,
      onSignedIn: () => calls.add('abre o escopo'),
      // Assíncrono, como o popScopesTill do get_it.
      onSignedOut: () async {
        await Future<void>.delayed(Duration.zero);
        calls.add('fecha o escopo');
      },
    );
    gate.addListener(() => calls.add('avisa o roteador'));
    addTearDown(gate.dispose);
    return gate;
  }

  test('uma sessão restaurada no boot abre o escopo na hora', () {
    final session = gate(initial: const SessionAuthenticated());

    expect(session.authenticated, isTrue);
    expect(calls, ['abre o escopo']);
  });

  test('o login abre o escopo e avisa o roteador', () async {
    final session = gate();

    changes.add(const SessionAuthenticated());
    await pumpEventQueue();

    expect(session.authenticated, isTrue);
    expect(calls, ['abre o escopo', 'avisa o roteador']);
  });

  test('o fim da sessão fecha o escopo antes de avisar o roteador', () async {
    final session = gate(initial: const SessionAuthenticated());
    calls.clear();

    changes.add(const SessionUnauthenticated());
    await pumpEventQueue();

    expect(session.authenticated, isFalse);
    expect(calls, ['fecha o escopo', 'avisa o roteador']);
  });

  test('o boot espera a sessão guardada ser lida', () async {
    final session = gate();
    final logger = FakeLogger();

    final waiting = session.waitUntilKnown(
      timeout: const Duration(seconds: 1),
      logger: logger,
    );
    changes.add(const SessionAuthenticated());
    await waiting;

    expect(session.authenticated, isTrue);
    expect(logger.logs, isEmpty);
  });

  test('passado o tempo, o boot segue sem sessão e registra', () async {
    final session = gate();
    final logger = FakeLogger();

    await session.waitUntilKnown(
      timeout: const Duration(milliseconds: 50),
      logger: logger,
    );

    expect(session.authenticated, isFalse);
    expect(logger.logs, ['boot: sessão guardada não lida a tempo']);

    // A leitura que chega depois ainda leva o usuário adiante.
    changes.add(const SessionAuthenticated());
    await pumpEventQueue();
    expect(calls, ['abre o escopo', 'avisa o roteador']);
  });

  test('a sessão expirada com alterações pendentes leva ao login sem fechar '
      'o escopo', () async {
    final session = gate(initial: const SessionAuthenticated());
    calls.clear();

    changes.add(const SessionExpiredWithPendingChanges(pendingChanges: 2));
    await pumpEventQueue();

    expect(session.authenticated, isFalse);
    expect(calls, ['avisa o roteador']);

    // Entrar de novo não abre um segundo escopo: a guarda do
    // openSessionScope cuida disso no app.
    changes.add(const SessionAuthenticated());
    await pumpEventQueue();
    expect(calls, ['avisa o roteador', 'abre o escopo', 'avisa o roteador']);
  });
}
