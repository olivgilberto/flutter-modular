import 'package:go_router/go_router.dart';

import '../pages/login_page.dart';
import '../pages/register_page.dart';

/// Os nomes e caminhos das rotas do módulo, no formato `[módulo].[tela]` e
/// `/[módulo]/[tela]`. Os nomes fazem parte do contrato público do módulo
/// (docs/modules/auth_module.md): o host os usa no redirect.
abstract final class AuthRoutes {
  static const prefix = '/auth';
  static const login = 'auth.login';
  static const loginPath = '$prefix/login';
  static const register = 'auth.register';
  static const registerPath = '$prefix/register';
}

/// A lista que o host espalha no `GoRouter` (capítulo 28). O módulo nunca
/// registra rotas num roteador global, e a lista não pode ser alterada por
/// quem a recebe.
final List<RouteBase> authModuleRoutes = List.unmodifiable([
  GoRoute(
    name: AuthRoutes.login,
    path: AuthRoutes.loginPath,
    builder: (context, state) => const LoginPage(),
  ),
  GoRoute(
    name: AuthRoutes.register,
    path: AuthRoutes.registerPath,
    builder: (context, state) => const RegisterPage(),
  ),
]);
