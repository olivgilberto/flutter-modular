part of 'session_bloc.dart';

/// Os quatro estados que o host conhece. Os três sem campos são
/// constantes: emitir o mesmo de novo não avisa ninguém.
sealed class SessionState {
  const SessionState();
}

/// Antes de a sessão guardada ser lida, no boot.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated();
}

/// Ninguém entrou, ou a sessão terminou e os dados já foram apagados.
final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

/// A sessão caiu no servidor, mas há alterações feitas sem conexão que
/// ainda não foram enviadas (capítulo 11). Os dados continuam no aparelho
/// e o escopo da sessão continua aberto, à espera da decisão do usuário na
/// tela de login: entrar de novo, para enviá-las, ou descartá-las.
final class SessionExpiredWithPendingChanges extends SessionState {
  const SessionExpiredWithPendingChanges({required this.pendingChanges});

  /// Quantas, ou `null` quando não foi possível contar.
  final int? pendingChanges;
}
