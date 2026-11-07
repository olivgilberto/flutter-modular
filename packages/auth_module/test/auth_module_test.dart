import 'package:auth_module/adapters/driven/auth_token_provider.dart';
import 'package:auth_module/adapters/driving/bloc/login_bloc.dart';
import 'package:auth_module/adapters/driving/bloc/logout_bloc.dart';
import 'package:auth_module/adapters/driving/bloc/register_bloc.dart';
import 'package:auth_module/application/ports/auth_repository.dart';
import 'package:auth_module/application/use_cases/auth_use_case.dart';
import 'package:auth_module/auth_module.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'fakes.dart';
import 'support/ffi_local_database.dart';

final class _MockApiClient extends Mock implements ApiClient {}

void main() {
  test('o módulo registra a porta do core, o caso de uso, as fábricas dos '
      'Blocs e um único SessionBloc', () async {
    final getIt = GetIt.asNewInstance()
      ..registerSingleton<ApiClient>(_MockApiClient())
      ..registerSingleton<LocalDatabaseFactory>(FfiLocalDatabaseFactory())
      ..registerSingleton<LogoutCleanerRegistry>(DefaultLogoutCleanerRegistry())
      ..registerSingleton<OutboxRegistry>(DefaultOutboxRegistry())
      ..registerSingleton<AppLogger>(FakeLogger())
      ..registerSingleton<AppAnalytics>(FakeAnalytics());

    registerAuthModuleDependencies(getIt);

    expect(getIt<TokenProvider>(), isA<AuthTokenProvider>());
    expect(getIt<AuthRepository>(), isNotNull);
    expect(getIt<AuthUseCase>(), isNotNull);
    final login = getIt<LoginBloc>();
    addTearDown(login.close);
    final otherLogin = getIt<LoginBloc>();
    addTearDown(otherLogin.close);
    expect(otherLogin, isNot(same(login)));
    final register = getIt<RegisterBloc>();
    addTearDown(register.close);
    final logout = getIt<LogoutBloc>();
    addTearDown(logout.close);
    expect(getIt<SessionBloc>(), same(getIt<SessionBloc>()));

    await getIt.reset();
    expect(getIt.isRegistered<SessionBloc>(), isFalse);
  });
}
