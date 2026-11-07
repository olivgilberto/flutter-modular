part of 'login_bloc.dart';

/// Os estados nunca sobrescrevem o `==`: cada emissão chega à tela.
sealed class LoginState {
  const LoginState();
}

final class LoginInitial extends LoginState {
  const LoginInitial();
}

final class LoginSubmitInProgress extends LoginState {
  const LoginSubmitInProgress();
}

/// O login deu certo. A tela não navega: o redirect do host, que observa
/// a sessão, leva o usuário adiante.
final class LoginSubmitSuccess extends LoginState {
  const LoginSubmitSuccess();
}

final class LoginSubmitFailure extends LoginState {
  const LoginSubmitFailure(AuthFailure this.failure);
  const LoginSubmitFailure.unavailable() : failure = null;

  /// A falha de negócio, ou `null` quando a causa foi técnica.
  final AuthFailure? failure;
}
