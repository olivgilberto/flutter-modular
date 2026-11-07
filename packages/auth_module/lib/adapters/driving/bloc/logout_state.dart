part of 'logout_bloc.dart';

/// Os estados nunca sobrescrevem o `==`: cada emissão chega à tela.
sealed class LogoutState {
  const LogoutState();
}

final class LogoutInitial extends LogoutState {
  const LogoutInitial();
}

final class LogoutCheckInProgress extends LogoutState {
  const LogoutCheckInProgress();
}

final class LogoutCheckSuccess extends LogoutState {
  const LogoutCheckSuccess({required this.pendingChanges});

  /// Quantas alterações feitas sem rede seriam perdidas.
  final int pendingChanges;
}

/// Não foi possível contar as alterações pendentes.
final class LogoutCheckFailure extends LogoutState {
  const LogoutCheckFailure();
}

final class LogoutSubmitInProgress extends LogoutState {
  const LogoutSubmitInProgress();
}

/// A sessão acabou. A View não navega: o redirect do host, que observa o
/// `SessionBloc`, leva ao login.
final class LogoutSubmitSuccess extends LogoutState {
  const LogoutSubmitSuccess();
}

/// A limpeza dos dados locais falhou. A sessão acabou mesmo assim, e o
/// erro já chegou ao registro de falhas pelo caso de uso.
final class LogoutSubmitFailure extends LogoutState {
  const LogoutSubmitFailure();
}
