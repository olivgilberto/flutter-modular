part of 'register_bloc.dart';

sealed class RegisterState {
  const RegisterState();
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

final class RegisterSubmitInProgress extends RegisterState {
  const RegisterSubmitInProgress();
}

/// A conta foi criada e a sessão já começou; como no login, quem leva o
/// usuário adiante é o host.
final class RegisterSubmitSuccess extends RegisterState {
  const RegisterSubmitSuccess();
}

final class RegisterSubmitFailure extends RegisterState {
  const RegisterSubmitFailure(AuthFailure this.failure);
  const RegisterSubmitFailure.unavailable() : failure = null;

  final AuthFailure? failure;
}
