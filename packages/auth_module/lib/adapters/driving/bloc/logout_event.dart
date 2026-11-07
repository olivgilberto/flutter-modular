part of 'logout_bloc.dart';

sealed class LogoutEvent {
  const LogoutEvent();
}

/// O toque em "Sair": primeiro, contar o que ainda não foi enviado.
final class LogoutRequested extends LogoutEvent {
  const LogoutRequested();
}

/// A decisão de sair, direta (nada pendente) ou confirmada pelo usuário.
final class LogoutConfirmed extends LogoutEvent {
  const LogoutConfirmed();
}
