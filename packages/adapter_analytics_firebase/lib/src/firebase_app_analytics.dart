import 'package:core/core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// [AppAnalytics] com Google Analytics for Firebase. Nunca lança: uma falha
/// do plugin vai para o [AppLogger], em vez de virar um erro assíncrono que
/// os handlers globais registrariam como fatal (o UseCase não espera
/// eventos). Sem Firebase inicializado, escreve no console.
final class FirebaseAppAnalytics implements AppAnalytics {
  FirebaseAppAnalytics({
    required AppLogger logger,
    FirebaseAnalytics? analytics,
  }) : _logger = logger,
       _injected = analytics;

  final AppLogger _logger;
  final FirebaseAnalytics? _injected;

  FirebaseAnalytics? get _analytics =>
      _injected ?? (Firebase.apps.isEmpty ? null : FirebaseAnalytics.instance);

  /// `[módulo]_[objeto]_[ação]`: snake_case, pelo menos três partes,
  /// começando por letra.
  static final _eventName = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+){2,}$');
  static const _reservedPrefixes = ['firebase_', 'google_', 'ga_'];

  /// Usado num assert: um nome inválido aparece na primeira execução em
  /// debug, não semanas depois no console do Firebase.
  static bool isValidEventName(String name) =>
      name.length <= 40 &&
      _eventName.hasMatch(name) &&
      !_reservedPrefixes.any(name.startsWith);

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const {},
  ]) async {
    assert(isValidEventName(name), 'Nome de evento inválido: $name');
    final analytics = _analytics;
    if (analytics == null) {
      debugPrint('[analytics] $name $parameters');
      return;
    }
    try {
      await analytics.logEvent(
        name: name,
        parameters: parameters.isEmpty ? null : parameters,
      );
    } on Exception catch (error, stackTrace) {
      _logger.error('analytics event', error, stackTrace);
    }
  }

  @override
  Future<void> logScreenView(String screenName) async {
    final analytics = _analytics;
    if (analytics == null) {
      debugPrint('[analytics] screen $screenName');
      return;
    }
    try {
      await analytics.logScreenView(screenName: screenName);
    } on Exception catch (error, stackTrace) {
      _logger.error('analytics screen view', error, stackTrace);
    }
  }
}
