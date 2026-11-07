import 'package:auth_module/adapters/driven/auth_token_provider.dart';
import 'package:auth_module/adapters/driven/models/auth_model.dart';
import 'package:auth_module/adapters/driven/services/auth_session_local_service.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'driven_fakes.dart';

/// Um banco que falha na primeira leitura e responde na segunda.
final class _FlakySessionLocal implements AuthSessionLocalService {
  var reads = 0;

  @override
  Future<AuthModel?> read() async {
    if (++reads == 1) throw const LocalDatabaseError('banco indisponível');
    return ana;
  }

  @override
  Future<void> write(AuthModel session) async {}

  @override
  Future<void> delete() async {}
}

void main() {
  test('o token vem da sessão guardada, lida uma vez', () async {
    final local = FakeSessionLocal(ana);
    final provider = AuthTokenProvider(local: local, remote: FakeTokenRemote());

    expect(await provider.currentToken(), 'at-1');
    expect(await provider.currentToken(), 'at-1');
    expect(local.reads, 1);
  });

  test('sem sessão, nada a renovar', () async {
    final remote = FakeTokenRemote();
    final provider = AuthTokenProvider(
      local: FakeSessionLocal(),
      remote: remote,
    );

    expect(await provider.refreshToken(), isNull);
    expect(remote.calls, 0);
  });

  test('chamadas simultâneas geram uma só renovação', () async {
    final local = FakeSessionLocal(ana);
    final remote = FakeTokenRemote();
    final provider = AuthTokenProvider(local: local, remote: remote);

    final results = await Future.wait([
      for (var i = 0; i < 5; i++) provider.refreshToken(),
    ]);

    expect(results.toSet(), {'at-2'});
    expect(remote.calls, 1);
    expect(local.row?.refreshToken, 'rt-2');
  });

  test('recusa do backend apaga a sessão e avisa que expirou', () async {
    final local = FakeSessionLocal(ana);
    final provider = AuthTokenProvider(
      local: local,
      remote: FakeTokenRemote(
        error: const ApiError(ApiErrorKind.rejected, statusCode: 401),
      ),
    );
    final expired = provider.expirations.first;

    expect(await provider.refreshToken(), isNull);
    await expectLater(expired, completes);
    expect(local.row, isNull);
    expect(await provider.currentToken(), isNull);
  });

  test('sem rede, a sessão continua e o erro sobe', () async {
    final local = FakeSessionLocal(ana);
    final provider = AuthTokenProvider(
      local: local,
      remote: FakeTokenRemote(error: const ApiError(ApiErrorKind.unreachable)),
    );

    await expectLater(provider.refreshToken(), throwsA(isA<ApiError>()));
    expect(local.row, ana);
  });

  test('uma leitura que falhou é tentada de novo na próxima chamada', () async {
    final local = _FlakySessionLocal();
    final provider = AuthTokenProvider(local: local, remote: FakeTokenRemote());

    await expectLater(
      provider.currentToken(),
      throwsA(isA<LocalDatabaseError>()),
    );
    expect(await provider.currentToken(), 'at-1');
    expect(local.reads, 2);
  });
}
