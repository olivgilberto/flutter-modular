import 'dart:async';

import 'package:core/core.dart';

import 'auth_session_store.dart';
import 'models/auth_model.dart';
import 'services/auth_session_local_service.dart';
import 'services/auth_token_remote_service.dart';

/// A sessão do app. Para o `core`, um [TokenProvider]: assina as
/// requisições e renova o token. Para o módulo, um [AuthSessionStore]:
/// guarda a sessão no login e a apaga no logout. Uma instância, dois papéis
/// (capítulo 8), registrada pela função do módulo.
final class AuthTokenProvider implements TokenProvider, AuthSessionStore {
  AuthTokenProvider({
    required AuthSessionLocalService local,
    required AuthTokenRemoteService remote,
  }) : _local = local,
       _remote = remote;

  final AuthSessionLocalService _local;
  final AuthTokenRemoteService _remote;
  final _expirations = StreamController<void>.broadcast();

  AuthModel? _session;

  /// A sessão guardada é lida do banco uma vez; depois, a memória
  /// acompanha cada gravação. Uma leitura que falhou é esquecida, para que
  /// a próxima tente de novo.
  Future<void>? _loading;

  Future<String?>? _refreshing;

  @override
  Future<String?> currentToken() async => (await current())?.accessToken;

  /// Chamadas simultâneas compartilham a mesma renovação (capítulo 11).
  @override
  Future<String?> refreshToken() =>
      _refreshing ??= _renew().whenComplete(() => _refreshing = null);

  Future<String?> _renew() async {
    final session = await current();
    if (session == null) return null;
    try {
      final tokens = await _remote.renew(session.refreshToken);
      final renewed = session.withTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      await save(renewed);
      return renewed.accessToken;
    } on ApiError catch (error) {
      // Sem rede, a sessão continua: a renovação tenta de novo depois.
      if (error.kind != ApiErrorKind.rejected) rethrow;
      await clear();
      _expirations.add(null);
      return null;
    }
  }

  Future<void> _loaded() => _loading ??= _local
      .read()
      .then<void>((stored) => _session = stored)
      .catchError((Object error, StackTrace stackTrace) {
        _loading = null;
        Error.throwWithStackTrace(error, stackTrace);
      });

  @override
  Future<AuthModel?> current() async {
    await _loaded();
    return _session;
  }

  @override
  Future<void> save(AuthModel session) async {
    await _loaded();
    await _local.write(session);
    _session = session;
  }

  @override
  Future<void> clear() async {
    await _loaded();
    _session = null;
    await _local.delete();
  }

  @override
  Stream<void> get expirations => _expirations.stream;
}
