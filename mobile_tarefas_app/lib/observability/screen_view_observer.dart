import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/widgets.dart';

/// Registra cada tela que o usuário vê, pelo nome da rota no formato
/// `[dono].[tela]` (capítulo 7). Quem registra é o host; nenhum módulo
/// registra a própria tela (capítulo 14).
///
/// Um observer serve a um navegador só. O host cria um para o `GoRouter` e
/// outro para cada `ShellRoute`, que tem navegador próprio: sem ele, as
/// telas da moldura nunca seriam vistas.
final class ScreenViewObserver extends NavigatorObserver {
  ScreenViewObserver(this._analytics);

  final AppAnalytics _analytics;

  /// Só telas: um diálogo é uma rota, mas não é uma tela. Uma rota sem nome
  /// não diz que tela é e fica de fora.
  void _record(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (route is PageRoute && name != null) {
      unawaited(_analytics.logScreenView(name));
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _record(newRoute);

  /// Voltar também é ver uma tela: a que reaparece.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record(previousRoute);
}
