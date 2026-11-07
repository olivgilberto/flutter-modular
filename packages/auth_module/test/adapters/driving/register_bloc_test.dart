import 'package:auth_module/adapters/driving/bloc/register_bloc.dart';
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

  void registerAnswers(Future<User> Function() answer) => when(
    () => auth.registerAccount(
      name: any(named: 'name'),
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => answer());

  const submitted = RegisterSubmitted(
    name: 'Ana',
    email: 'ana@exemplo.com',
    password: strongPassword,
  );

  blocTest<RegisterBloc, RegisterState>(
    'cria a conta e emite InProgress e Success',
    setUp: () => registerAnswers(() async => ana),
    build: () => RegisterBloc(auth: auth),
    act: (bloc) => bloc.add(submitted),
    expect: () => [
      isA<RegisterSubmitInProgress>(),
      isA<RegisterSubmitSuccess>(),
    ],
  );

  blocTest<RegisterBloc, RegisterState>(
    'e-mail já cadastrado vira um estado de falha que o carrega',
    setUp: () => registerAnswers(
      () => Future.error(const EmailAlreadyRegisteredFailure()),
    ),
    build: () => RegisterBloc(auth: auth),
    act: (bloc) => bloc.add(submitted),
    expect: () => [
      isA<RegisterSubmitInProgress>(),
      isA<RegisterSubmitFailure>().having(
        (state) => state.failure,
        'failure',
        isA<EmailAlreadyRegisteredFailure>(),
      ),
    ],
  );

  for (final (name, error) in [
    ('ApiError', const ApiError(ApiErrorKind.server, statusCode: 503)),
    ('LocalDatabaseError', const LocalDatabaseError('session write')),
  ]) {
    blocTest<RegisterBloc, RegisterState>(
      '$name vira a falha técnica, sem Failure',
      setUp: () => registerAnswers(() => Future.error(error)),
      build: () => RegisterBloc(auth: auth),
      act: (bloc) => bloc.add(submitted),
      expect: () => [
        isA<RegisterSubmitInProgress>(),
        isA<RegisterSubmitFailure>().having(
          (state) => state.failure,
          'failure',
          isNull,
        ),
      ],
    );
  }
}
