import 'dart:async';

import 'package:auth_module/adapters/driving/bloc/login_bloc.dart';
import 'package:auth_module/domain/auth_failure.dart';
import 'package:auth_module/domain/entities/user.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'driving_mocks.dart';

void main() {
  late MockAuthUseCase auth;

  setUp(() => auth = MockAuthUseCase());

  void signInAnswers(Future<User> Function() answer) => when(
    () => auth.signInWithPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => answer());

  const submitted = LoginSubmitted(
    email: 'ana@exemplo.com',
    password: strongPassword,
  );

  blocTest<LoginBloc, LoginState>(
    'entrega o texto cru ao caso de uso e emite InProgress e Success',
    setUp: () => signInAnswers(() async => ana),
    build: () => LoginBloc(auth: auth),
    act: (bloc) => bloc.add(submitted),
    expect: () => [isA<LoginSubmitInProgress>(), isA<LoginSubmitSuccess>()],
    verify: (_) => verify(
      () => auth.signInWithPassword(
        email: 'ana@exemplo.com',
        password: strongPassword,
      ),
    ).called(1),
  );

  blocTest<LoginBloc, LoginState>(
    'uma Failure vira um estado de falha que a carrega',
    setUp: () =>
        signInAnswers(() => Future.error(const InvalidCredentialsFailure())),
    build: () => LoginBloc(auth: auth),
    act: (bloc) => bloc.add(submitted),
    expect: () => [
      isA<LoginSubmitInProgress>(),
      isA<LoginSubmitFailure>().having(
        (state) => state.failure,
        'failure',
        isA<InvalidCredentialsFailure>(),
      ),
    ],
  );

  for (final (name, error) in [
    ('ApiError', const ApiError(ApiErrorKind.unreachable)),
    ('LocalDatabaseError', const LocalDatabaseError('session write')),
  ]) {
    blocTest<LoginBloc, LoginState>(
      '$name vira a falha técnica, sem Failure',
      setUp: () => signInAnswers(() => Future.error(error)),
      build: () => LoginBloc(auth: auth),
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<LoginSubmitInProgress>(),
        isA<LoginSubmitFailure>().having(
          (state) => state.failure,
          'failure',
          isNull,
        ),
      ],
    );
  }

  blocTest<LoginBloc, LoginState>(
    'um bug não é capturado: chega ao onError e nenhum estado de falha sai',
    setUp: () => signInAnswers(() => Future.error(StateError('bug'))),
    build: () => LoginBloc(auth: auth),
    act: (bloc) => bloc.add(submitted),
    expect: () => [isA<LoginSubmitInProgress>()],
    errors: () => [isA<StateError>()],
  );

  final pending = Completer<User>();
  blocTest<LoginBloc, LoginState>(
    'droppable: um segundo envio durante o primeiro é ignorado',
    setUp: () => signInAnswers(() => pending.future),
    build: () => LoginBloc(auth: auth),
    act: (bloc) async {
      bloc
        ..add(submitted)
        ..add(submitted);
      await Future<void>.delayed(Duration.zero);
      pending.complete(ana);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [isA<LoginSubmitInProgress>(), isA<LoginSubmitSuccess>()],
    verify: (_) => verify(
      () => auth.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).called(1),
  );
}
