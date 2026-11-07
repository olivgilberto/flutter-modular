import 'dart:async';

import 'package:auth_module/adapters/driving/session/session_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'driving_mocks.dart';

void main() {
  late MockAuthUseCase auth;
  late StreamController<bool> signedIn;
  late StreamController<void> expired;

  setUp(() {
    auth = MockAuthUseCase();
    signedIn = StreamController<bool>.broadcast();
    expired = StreamController<void>.broadcast();
    when(() => auth.watchSignedIn()).thenAnswer((_) => signedIn.stream);
    when(() => auth.watchSessionExpired()).thenAnswer((_) => expired.stream);
  });

  test('começa sem saber, antes de a sessão guardada ser lida', () async {
    final bloc = SessionBloc(auth: auth);
    addTearDown(bloc.close);

    expect(bloc.state, isA<SessionUnknown>());
  });

  blocTest<SessionBloc, SessionState>(
    'segue o que o caso de uso publica, venha de que tela vier',
    build: () => SessionBloc(auth: auth),
    act: (_) async {
      signedIn.add(true);
      await pumpEventQueue();
      signedIn.add(true);
      await pumpEventQueue();
      signedIn.add(false);
    },
    // O segundo `true` não é emitido de novo: o estado é o mesmo.
    expect: () => [isA<SessionAuthenticated>(), isA<SessionUnauthenticated>()],
  );

  blocTest<SessionBloc, SessionState>(
    'a restauração é pedida ao caso de uso, e o resultado chega pelo que ele '
    'publica',
    setUp: () => when(() => auth.restoreSession()).thenAnswer((_) async {
      signedIn.add(true);
      return ana;
    }),
    build: () => SessionBloc(auth: auth),
    act: (bloc) => bloc.add(const SessionRestoreRequested()),
    expect: () => [isA<SessionAuthenticated>()],
    verify: (_) => verify(() => auth.restoreSession()).called(1),
  );

  blocTest<SessionBloc, SessionState>(
    'um banco da sessão ilegível vira sessão nenhuma',
    setUp: () => when(
      () => auth.restoreSession(),
    ).thenThrow(const LocalDatabaseError('ilegível')),
    build: () => SessionBloc(auth: auth),
    act: (bloc) => bloc.add(const SessionRestoreRequested()),
    expect: () => [isA<SessionUnauthenticated>()],
  );

  group('sessão expirada', () {
    setUp(
      () => when(
        () => auth.endExpiredSession(),
      ).thenAnswer((_) async => signedIn.add(false)),
    );

    blocTest<SessionBloc, SessionState>(
      'sem alterações pendentes, termina pelo caso de uso',
      setUp: () => when(() => auth.pendingChanges()).thenAnswer((_) async => 0),
      build: () => SessionBloc(auth: auth),
      act: (_) => expired.add(null),
      expect: () => [isA<SessionUnauthenticated>()],
      verify: (_) => verify(() => auth.endExpiredSession()).called(1),
    );

    blocTest<SessionBloc, SessionState>(
      'com alterações pendentes, espera a decisão e não apaga nada',
      setUp: () => when(() => auth.pendingChanges()).thenAnswer((_) async => 2),
      build: () => SessionBloc(auth: auth),
      act: (_) => expired.add(null),
      expect: () => [
        isA<SessionExpiredWithPendingChanges>().having(
          (state) => state.pendingChanges,
          'pendingChanges',
          2,
        ),
      ],
      verify: (_) => verifyNever(() => auth.endExpiredSession()),
    );

    blocTest<SessionBloc, SessionState>(
      'sem conseguir contar, também espera, sem número',
      setUp: () => when(
        () => auth.pendingChanges(),
      ).thenThrow(const LocalDatabaseError('fila ilegível')),
      build: () => SessionBloc(auth: auth),
      act: (_) => expired.add(null),
      expect: () => [
        isA<SessionExpiredWithPendingChanges>().having(
          (state) => state.pendingChanges,
          'pendingChanges',
          isNull,
        ),
      ],
      verify: (_) => verifyNever(() => auth.endExpiredSession()),
    );

    blocTest<SessionBloc, SessionState>(
      'descartar termina a sessão pelo caso de uso',
      seed: () => const SessionExpiredWithPendingChanges(pendingChanges: 2),
      build: () => SessionBloc(auth: auth),
      act: (bloc) => bloc.add(const SessionDiscardRequested()),
      expect: () => [isA<SessionUnauthenticated>()],
      verify: (_) => verify(() => auth.endExpiredSession()).called(1),
    );

    blocTest<SessionBloc, SessionState>(
      'entrar de novo volta à sessão aberta, sem descartar nada',
      seed: () => const SessionExpiredWithPendingChanges(pendingChanges: 2),
      build: () => SessionBloc(auth: auth),
      act: (_) => signedIn.add(true),
      expect: () => [isA<SessionAuthenticated>()],
      verify: (_) => verifyNever(() => auth.endExpiredSession()),
    );
  });

  test('fechado, deixa de escutar o caso de uso', () async {
    final bloc = SessionBloc(auth: auth);
    expect(signedIn.hasListener, isTrue);

    await bloc.close();

    expect(signedIn.hasListener, isFalse);
    expect(expired.hasListener, isFalse);
  });
}
