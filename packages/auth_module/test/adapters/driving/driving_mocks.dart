import 'package:auth_module/adapters/driving/bloc/login_bloc.dart';
import 'package:auth_module/adapters/driving/bloc/logout_bloc.dart';
import 'package:auth_module/adapters/driving/bloc/register_bloc.dart';
import 'package:auth_module/application/use_cases/auth_use_case.dart';
import 'package:auth_module/domain/entities/user.dart';
import 'package:auth_module/domain/value_objects/email_address.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

/// Possível porque o `AuthUseCase` não é `final` (capítulo 20).
final class MockAuthUseCase extends Mock implements AuthUseCase {}

/// Possíveis porque os Blocs não são `final`.
final class MockLoginBloc extends MockBloc<LoginEvent, LoginState>
    implements LoginBloc {}

final class MockRegisterBloc extends MockBloc<RegisterEvent, RegisterState>
    implements RegisterBloc {}

final class MockLogoutBloc extends MockBloc<LogoutEvent, LogoutState>
    implements LogoutBloc {}

final ana = User(
  id: 'u-1',
  name: 'Ana',
  email: EmailAddress.parse('ana@exemplo.com'),
);

const strongPassword = 'cavalo-bateria-grampo';
