import 'package:auth_module/adapters/driven/auth_api_paths.dart';
import 'package:auth_module/adapters/driven/models/auth_model.dart';
import 'package:auth_module/adapters/driven/services/rest_auth_service.dart';
import 'package:auth_module/domain/auth_failure.dart';
import 'package:auth_module/domain/value_objects/email_address.dart';
import 'package:auth_module/domain/value_objects/password.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'driven_fakes.dart';

final class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient api;
  late FakeSessionStore session;
  late RestAuthService service;
  final email = EmailAddress.parse('ana@exemplo.com');
  final password = Password.parse('cavalo-bateria-grampo');

  Map<String, Object?> response({String email = 'ana@exemplo.com'}) => {
    'user': {'id': 'u-1', 'name': 'Ana', 'email': email},
    'accessToken': 'at-1',
    'refreshToken': 'rt-1',
  };

  void rejectWith(String path, int status, String code) {
    when(() => api.post(path, body: any(named: 'body'))).thenThrow(
      ApiError(ApiErrorKind.rejected, statusCode: status, body: {'code': code}),
    );
  }

  setUp(() {
    api = MockApiClient();
    session = FakeSessionStore();
    service = RestAuthService(apiClient: api, session: session);
  });

  test('login converte a resposta e guarda a sessão', () async {
    when(
      () => api.post(AuthApiPaths.signIn, body: any(named: 'body')),
    ).thenAnswer((_) async => response());

    final user = await service.signInWithPassword(email, password);

    expect(user.id, 'u-1');
    expect(session.stored?.refreshToken, 'rt-1');
    final body =
        verify(
              () => api.post(
                AuthApiPaths.signIn,
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map;
    expect(body, {'email': 'ana@exemplo.com', 'password': password.value});
  });

  test('401 com invalid_credentials vira Failure', () async {
    rejectWith(AuthApiPaths.signIn, 401, 'invalid_credentials');

    await expectLater(
      service.signInWithPassword(email, password),
      throwsA(isA<InvalidCredentialsFailure>()),
    );
  });

  test('422 com email_already_registered vira Failure', () async {
    rejectWith(AuthApiPaths.register, 422, 'email_already_registered');

    await expectLater(
      service.registerAccount(name: 'Ana', email: email, password: password),
      throwsA(isA<EmailAlreadyRegisteredFailure>()),
    );
  });

  test('422 com weak_password vira a mesma falha do domínio', () async {
    rejectWith(AuthApiPaths.register, 422, 'weak_password');

    await expectLater(
      service.registerAccount(name: 'Ana', email: email, password: password),
      throwsA(isA<WeakPasswordFailure>()),
    );
  });

  test('422 com código desconhecido continua técnico', () async {
    rejectWith(AuthApiPaths.register, 422, 'algo_novo');

    await expectLater(
      service.registerAccount(name: 'Ana', email: email, password: password),
      throwsA(isA<ApiError>()),
    );
  });

  test(
    'e-mail inválido vindo do servidor não vira Failure nem sessão',
    () async {
      when(
        () => api.post(AuthApiPaths.signIn, body: any(named: 'body')),
      ).thenAnswer((_) async => response(email: 'sem-arroba'));

      await expectLater(
        service.signInWithPassword(email, password),
        throwsA(
          isA<ApiError>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.invalidResponse,
          ),
        ),
      );
      expect(session.stored, isNull);
    },
  );

  test('logout apaga a sessão mesmo se o backend falhar', () async {
    session.stored = ana;
    when(
      () => api.post(AuthApiPaths.signOut),
    ).thenThrow(const ApiError(ApiErrorKind.server, statusCode: 503));

    await expectLater(service.signOut(), throwsA(isA<ApiError>()));
    expect(session.stored, isNull);
  });

  test('a sessão é restaurada do aparelho, sem rede', () async {
    session.stored = ana;

    final user = await service.restoreSession();

    expect(user?.id, 'u-1');
    verifyNoMoreInteractions(api);
  });

  test('uma sessão guardada com e-mail inválido é falha técnica', () async {
    session.stored = const AuthModel(
      userId: 'u-1',
      name: 'Ana',
      email: 'sem-arroba',
      accessToken: 'at-1',
      refreshToken: 'rt-1',
    );

    await expectLater(
      service.restoreSession(),
      throwsA(isA<LocalDatabaseError>()),
    );
  });

  test('a expiração da sessão chega pela porta', () async {
    final expired = service.watchSessionExpired().first;

    session.expired.add(null);

    await expectLater(expired, completes);
  });
}
