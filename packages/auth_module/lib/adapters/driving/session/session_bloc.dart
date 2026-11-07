import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/use_cases/auth_use_case.dart';

part 'session_event.dart';
part 'session_state.dart';

/// O estado da sessão que o módulo publica para o host (capítulo 11). É o
/// contrato da autenticação com o host, no lugar do token: só muda para
/// [SessionUnauthenticated] depois que a limpeza dos dados terminou.
///
/// Vive no escopo base, do boot ao fim do app, e escuta o caso de uso desde
/// que nasce: um login feito em qualquer tela chega aqui sem que a tela
/// saiba que este Bloc existe.
final class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc({required AuthUseCase auth})
    : _auth = auth,
      super(const SessionUnknown()) {
    on<SessionRestoreRequested>(_onRestoreRequested);
    on<_SignedInChanged>(
      (event, emit) => emit(
        event.signedIn
            ? const SessionAuthenticated()
            : const SessionUnauthenticated(),
      ),
    );
    on<_SessionExpired>(_onExpired);
    on<SessionDiscardRequested>(_onDiscardRequested);
    _subscriptions = [
      auth.watchSignedIn().listen(
        (signedIn) => add(_SignedInChanged(signedIn)),
      ),
      auth.watchSessionExpired().listen((_) => add(const _SessionExpired())),
    ];
  }

  final AuthUseCase _auth;
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// O caso de uso publica o resultado em `watchSignedIn`. Um banco da
  /// sessão ilegível vira "sem sessão": o usuário entra de novo.
  Future<void> _onRestoreRequested(
    SessionRestoreRequested event,
    Emitter<SessionState> emit,
  ) async {
    try {
      await _auth.restoreSession();
    } on LocalDatabaseError {
      emit(const SessionUnauthenticated());
    }
  }

  /// A renovação foi recusada: a sessão já caiu no servidor, e não há
  /// como pedir confirmação antes (capítulo 11). Sem alterações pendentes,
  /// ela termina aqui. Com alguma, o Bloc espera a decisão do usuário, e
  /// os dados ficam no aparelho até lá.
  Future<void> _onExpired(
    _SessionExpired event,
    Emitter<SessionState> emit,
  ) async {
    final int pending;
    try {
      pending = await _auth.pendingChanges();
    } on LocalDatabaseError {
      // Sem saber quantas, o usuário decide: nada é apagado sem ele.
      emit(const SessionExpiredWithPendingChanges(pendingChanges: null));
      return;
    }
    if (pending > 0) {
      emit(SessionExpiredWithPendingChanges(pendingChanges: pending));
      return;
    }
    await _end();
  }

  /// O usuário preferiu descartar as alterações a entrar de novo.
  Future<void> _onDiscardRequested(
    SessionDiscardRequested event,
    Emitter<SessionState> emit,
  ) => _end();

  /// O caso de uso publica o fim da sessão, que chega como
  /// [SessionUnauthenticated], mesmo quando a limpeza falha.
  Future<void> _end() async {
    try {
      await _auth.endExpiredSession();
    } on LocalDatabaseError {
      // Já foi para o registro de falhas pelo caso de uso.
    }
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
