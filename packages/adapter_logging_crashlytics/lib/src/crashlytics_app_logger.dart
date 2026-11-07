import 'dart:async';

import 'package:core/core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// [AppLogger] com Firebase Crashlytics:
///
/// | Porta                       | Crashlytics                              |
/// |-----------------------------|------------------------------------------|
/// | `log(message)`              | `log(message)`                           |
/// | `error(reason, error, st)`  | `recordError(error, st, reason: reason)` |
/// | `fatal(error, st)`          | `recordError(error, st, fatal: true)`    |
/// | `setUserId(id)`             | `setUserIdentifier(id ?? '')`            |
///
/// Enquanto nenhum app do Firebase foi inicializado (arquivos de
/// configuração ainda não gerados, ou o passo 1 do boot falhou), escreve no
/// console em vez de enviar. Em debug, também ecoa no console.
final class CrashlyticsAppLogger implements AppLogger {
  CrashlyticsAppLogger({FirebaseCrashlytics? crashlytics})
    : _injected = crashlytics;

  final FirebaseCrashlytics? _injected;

  /// Resolvido a cada chamada: `FirebaseCrashlytics.instance` lança antes
  /// do `Firebase.initializeApp()`.
  FirebaseCrashlytics? get _crashlytics =>
      _injected ??
      (Firebase.apps.isEmpty ? null : FirebaseCrashlytics.instance);

  @override
  void log(String message) {
    final crashlytics = _crashlytics;
    if (kDebugMode || crashlytics == null) debugPrint('[log] $message');
    if (crashlytics != null) unawaited(crashlytics.log(message));
  }

  @override
  void error(String reason, Object error, StackTrace stackTrace) {
    final crashlytics = _crashlytics;
    if (kDebugMode || crashlytics == null) {
      debugPrint('[error] $reason: $error\n$stackTrace');
    }
    if (crashlytics != null) {
      unawaited(crashlytics.recordError(error, stackTrace, reason: reason));
    }
  }

  @override
  void fatal(Object error, StackTrace stackTrace) {
    final crashlytics = _crashlytics;
    if (kDebugMode || crashlytics == null) {
      debugPrint('[fatal] $error\n$stackTrace');
    }
    if (crashlytics != null) {
      unawaited(crashlytics.recordError(error, stackTrace, fatal: true));
    }
  }

  @override
  void setUserId(String? opaqueId) {
    final crashlytics = _crashlytics;
    if (crashlytics != null) {
      unawaited(crashlytics.setUserIdentifier(opaqueId ?? ''));
    }
  }
}
