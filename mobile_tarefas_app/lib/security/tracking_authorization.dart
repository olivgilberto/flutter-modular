import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// O App Tracking Transparency (capítulos 14 e 38). O Firebase Analytics
/// do projeto pode ler o identificador de publicidade do iOS, então o host
/// pede a permissão, uma vez, antes de qualquer rastreamento. Sem
/// permissão, o identificador vem zerado e nada mais muda: nenhuma
/// funcionalidade depende da resposta.
///
/// O pedido só aparece com o app ativo: a Apple ignora a chamada feita
/// antes disso, sem erro. Por isso ele não é o passo 2 do boot, que roda
/// antes do `runApp`, e sim a primeira coisa depois que a primeira tela
/// aparece e o app fica ativo.
Future<void> requestTrackingAuthorization({
  required AppLogger logger,
  bool Function() isIOS = _isIOS,
  Future<TrackingStatus> Function() status = _status,
  Future<TrackingStatus> Function() request = _request,
}) async {
  if (!isIOS()) return;
  try {
    if (await status() != TrackingStatus.notDetermined) return;
    final answer = await request();
    logger.log('tracking authorization: ${answer.name}');
  } on PlatformException catch (error, stackTrace) {
    logger.error('tracking authorization', error, stackTrace);
  }
}

/// Completa quando o app estiver ativo (`resumed`): na hora, se já
/// estiver; senão, na primeira vez que ficar.
Future<void> appActive(WidgetsBinding binding) {
  if (binding.lifecycleState == AppLifecycleState.resumed) {
    return Future.value();
  }
  final active = Completer<void>();
  late final AppLifecycleListener listener;
  listener = AppLifecycleListener(
    binding: binding,
    onStateChange: (state) {
      if (state == AppLifecycleState.resumed && !active.isCompleted) {
        listener.dispose();
        active.complete();
      }
    },
  );
  return active.future;
}

bool _isIOS() => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

Future<TrackingStatus> _status() =>
    AppTrackingTransparency.trackingAuthorizationStatus;

Future<TrackingStatus> _request() =>
    AppTrackingTransparency.requestTrackingAuthorization();
