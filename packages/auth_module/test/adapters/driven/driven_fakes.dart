import 'dart:async';

import 'package:auth_module/adapters/driven/auth_session_store.dart';
import 'package:auth_module/adapters/driven/models/auth_model.dart';
import 'package:auth_module/adapters/driven/services/auth_session_local_service.dart';
import 'package:auth_module/adapters/driven/services/auth_token_remote_service.dart';

const ana = AuthModel(
  userId: 'u-1',
  name: 'Ana',
  email: 'ana@exemplo.com',
  accessToken: 'at-1',
  refreshToken: 'rt-1',
);

final class FakeSessionStore implements AuthSessionStore {
  AuthModel? stored;
  final expired = StreamController<void>.broadcast();

  @override
  Future<AuthModel?> current() async => stored;

  @override
  Future<void> save(AuthModel session) async => stored = session;

  @override
  Future<void> clear() async => stored = null;

  @override
  Stream<void> get expirations => expired.stream;
}

final class FakeSessionLocal implements AuthSessionLocalService {
  FakeSessionLocal([this.row]);

  AuthModel? row;
  var reads = 0;

  @override
  Future<AuthModel?> read() async {
    reads++;
    return row;
  }

  @override
  Future<void> write(AuthModel session) async => row = session;

  @override
  Future<void> delete() async => row = null;
}

final class FakeTokenRemote implements AuthTokenRemoteService {
  FakeTokenRemote({this.error});

  final Object? error;
  var calls = 0;

  @override
  Future<({String accessToken, String refreshToken})> renew(
    String refreshToken,
  ) async {
    calls++;
    await Future<void>.delayed(Duration.zero);
    if (error case final error?) throw error;
    return (accessToken: 'at-${calls + 1}', refreshToken: 'rt-${calls + 1}');
  }
}
