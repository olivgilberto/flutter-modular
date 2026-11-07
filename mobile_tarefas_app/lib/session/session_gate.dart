import 'dart:async';

import 'package:auth_module/auth_module.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

/// O que o host faz com o estado da sessão que o auth_module publica
/// (capítulo 11): garante o escopo da sessão aberto quando alguém entra,
/// renova o escopo quando a sessão termina e só então avisa o roteador, e o
/// mantém como está quando ela expira com alterações não enviadas
/// (capítulo 32). O host observa o estado, nunca o token.
///
/// Recebe o estado e o stream, e não o `SessionBloc`, para ser testado sem
/// o módulo montado.
final class SessionGate extends ChangeNotifier {
  SessionGate({
    required SessionState initial,
    required Stream<SessionState> changes,
    required void Function() onSignedIn,
    required Future<void> Function() onSignedOut,
  }) : _state = initial,
       _onSignedIn = onSignedIn,
       _onSignedOut = onSignedOut {
    _subscription = changes.listen(_apply);
    if (initial is SessionAuthenticated) onSignedIn();
  }

  final void Function() _onSignedIn;
  final Future<void> Function() _onSignedOut;
  late final StreamSubscription<SessionState> _subscription;
  SessionState _state;
  final _known = Completer<void>();
  var _disposed = false;

  /// O que o redirect consulta. Enquanto a sessão guardada não foi lida, a
  /// resposta é "não": o pior caso é o login aparecer e sair sozinho.
  bool get authenticated => _state is SessionAuthenticated;

  Future<void> _apply(SessionState state) async {
    _state = state;
    switch (state) {
      case SessionAuthenticated():
        _onSignedIn();
      case SessionUnauthenticated():
        await _onSignedOut();
      case SessionExpiredWithPendingChanges():
        // O escopo continua aberto: os dados e as filas da sessão anterior
        // esperam a decisão do usuário na tela de login (capítulo 29).
        break;
      case SessionUnknown():
        return;
    }
    if (!_known.isCompleted) _known.complete();
    // O fechamento do escopo é assíncrono, e o app pode ter acabado nele.
    if (!_disposed) notifyListeners();
  }

  /// O fim do passo 5 do boot: espera a sessão guardada, com o mesmo tempo
  /// limite dos outros passos. Passado o tempo, o app abre sem sessão, e o
  /// redirect leva o usuário adiante quando a leitura terminar.
  Future<void> waitUntilKnown({
    required Duration timeout,
    required AppLogger logger,
  }) async {
    if (_state is! SessionUnknown) return;
    try {
      await _known.future.timeout(timeout);
    } on TimeoutException {
      logger.log('boot: sessão guardada não lida a tempo');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
