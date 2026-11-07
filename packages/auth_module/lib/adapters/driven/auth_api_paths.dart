/// Os caminhos do backend de autenticação, todos a partir de uma versão.
/// Nenhum outro arquivo do módulo escreve um caminho.
abstract final class AuthApiPaths {
  static const version = '/v1';

  static const signIn = '$version/auth/sign-in';
  static const register = '$version/auth/register';
  static const refresh = '$version/auth/refresh';
  static const signOut = '$version/auth/sign-out';
}
