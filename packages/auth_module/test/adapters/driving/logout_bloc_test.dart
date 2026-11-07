import 'package:auth_module/adapters/driving/bloc/logout_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'driving_mocks.dart';

void main() {
  late MockAuthUseCase auth;

  setUp(() => auth = MockAuthUseCase());

  blocTest<LogoutBloc, LogoutState>(
    'o pedido conta as alterações pendentes e não sai ainda',
    setUp: () => when(() => auth.pendingChanges()).thenAnswer((_) async => 2),
    build: () => LogoutBloc(auth: auth),
    act: (bloc) => bloc.add(const LogoutRequested()),
    expect: () => [
      isA<LogoutCheckInProgress>(),
      isA<LogoutCheckSuccess>().having(
        (state) => state.pendingChanges,
        'pendingChanges',
        2,
      ),
    ],
    verify: (_) => verifyNever(() => auth.signOut()),
  );

  blocTest<LogoutBloc, LogoutState>(
    'sem conseguir contar, o pedido termina em falha da verificação',
    setUp: () => when(
      () => auth.pendingChanges(),
    ).thenThrow(const LocalDatabaseError('fila ilegível')),
    build: () => LogoutBloc(auth: auth),
    act: (bloc) => bloc.add(const LogoutRequested()),
    expect: () => [isA<LogoutCheckInProgress>(), isA<LogoutCheckFailure>()],
  );

  blocTest<LogoutBloc, LogoutState>(
    'a confirmação encerra a sessão pelo caso de uso',
    setUp: () => when(() => auth.signOut()).thenAnswer((_) async {}),
    build: () => LogoutBloc(auth: auth),
    act: (bloc) => bloc.add(const LogoutConfirmed()),
    expect: () => [isA<LogoutSubmitInProgress>(), isA<LogoutSubmitSuccess>()],
    verify: (_) => verify(() => auth.signOut()).called(1),
  );

  blocTest<LogoutBloc, LogoutState>(
    'sem rede, a sessão acaba do mesmo jeito: os dados locais já se foram',
    setUp: () => when(
      () => auth.signOut(),
    ).thenThrow(const ApiError(ApiErrorKind.unreachable)),
    build: () => LogoutBloc(auth: auth),
    act: (bloc) => bloc.add(const LogoutConfirmed()),
    expect: () => [isA<LogoutSubmitInProgress>(), isA<LogoutSubmitSuccess>()],
  );

  blocTest<LogoutBloc, LogoutState>(
    'uma falha na limpeza termina em falha do envio',
    setUp: () => when(
      () => auth.signOut(),
    ).thenThrow(const LocalDatabaseError('banco travado')),
    build: () => LogoutBloc(auth: auth),
    act: (bloc) => bloc.add(const LogoutConfirmed()),
    expect: () => [isA<LogoutSubmitInProgress>(), isA<LogoutSubmitFailure>()],
  );
}
