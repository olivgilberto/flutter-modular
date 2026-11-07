part of 'session_bloc.dart';

sealed class SessionEvent {
  const SessionEvent();
}

/// Disparado pelo host no boot: lê a sessão guardada no aparelho.
final class SessionRestoreRequested extends SessionEvent {
  const SessionRestoreRequested();
}

/// Da tela de login, depois de uma sessão expirada com alterações não
/// enviadas: o usuário prefere descartá-las a entrar de novo.
final class SessionDiscardRequested extends SessionEvent {
  const SessionDiscardRequested();
}

/// Internos: o que o caso de uso publicou.
final class _SignedInChanged extends SessionEvent {
  const _SignedInChanged(this.signedIn);

  final bool signedIn;
}

final class _SessionExpired extends SessionEvent {
  const _SessionExpired();
}
