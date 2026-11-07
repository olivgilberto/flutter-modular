import 'package:core/core.dart';

/// Os desvios de negócio da autenticação: tudo o que o usuário pode
/// corrigir. Nenhuma falha carrega texto; a View decide a mensagem.
sealed class AuthFailure implements Failure {
  const AuthFailure();
}

/// O texto não tem o formato de um e-mail (verificado no aparelho).
final class InvalidEmailFailure extends AuthFailure {
  const InvalidEmailFailure();
}

/// A senha não atende à política (o tamanho, verificado no aparelho, ou a
/// lista de senhas comprometidas, verificada pelo backend).
final class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure();
}

/// O backend recusou o e-mail e a senha.
final class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure();
}

/// O backend já tem uma conta com esse e-mail.
final class EmailAlreadyRegisteredFailure extends AuthFailure {
  const EmailAlreadyRegisteredFailure();
}
