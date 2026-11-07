import 'package:auth_module/auth_module.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:tasks_module/tasks_module.dart';

import '../home/app_frame.dart';
import '../language/language_selection_page.dart';
import '../observability/screen_view_observer.dart';
import '../session/session_gate.dart';
import '../settings/app_settings.dart';

/// As rotas do próprio host, no formato `[dono].[tela]` dos módulos.
abstract final class HostRoutes {
  static const home = 'app.home';
  static const homePath = '/';
  static const language = 'app.language';
  static const languagePath = '/language';
}

/// O roteador do app: as rotas do host e as listas exportadas pelos
/// módulos, espalhadas. Reavalia o redirect sempre que as configurações ou
/// a sessão mudam. Com o [analytics], registra cada tela vista (capítulo
/// 38), no navegador principal e no da moldura.
GoRouter createAppRouter(
  AppSettings settings,
  SessionGate session, {
  AppAnalytics? analytics,
}) => GoRouter(
  initialLocation: HostRoutes.homePath,
  observers: [?_screenViews(analytics)],
  refreshListenable: Listenable.merge([settings, session]),
  redirect: (context, state) => appRedirect(
    state.uri,
    languageChosen: settings.locale != null,
    authenticated: session.authenticated,
  ),
  routes: [
    // A tela inicial de quem entrou é a lista de tarefas (capítulo 34).
    GoRoute(
      name: HostRoutes.home,
      path: HostRoutes.homePath,
      redirect: (context, state) => TaskRoutes.listPath,
    ),
    GoRoute(
      name: HostRoutes.language,
      path: HostRoutes.languagePath,
      builder: (context, state) =>
          LanguageSelectionPage(onSelected: settings.chooseLanguage),
    ),
    ...authModuleRoutes,
    // As telas do módulo de tarefas, dentro da moldura do host.
    ShellRoute(
      observers: [?_screenViews(analytics)],
      builder: (context, state, child) => AppFrame(child: child),
      routes: tasksModuleRoutes,
    ),
  ],
);

/// Um observer novo para cada navegador: um observer serve a um só.
ScreenViewObserver? _screenViews(AppAnalytics? analytics) =>
    analytics == null ? null : ScreenViewObserver(analytics);

/// O passo 10 do boot, como função pura: as regras em ordem, a primeira
/// que se aplica decide.
String? appRedirect(
  Uri uri, {
  required bool languageChosen,
  required bool authenticated,
}) {
  final atLanguage = uri.path == HostRoutes.languagePath;

  // 1. Idioma: nada abre antes da escolha, nem um link externo. O destino
  //    original segue junto e é retomado depois.
  if (!languageChosen) {
    if (atLanguage) return null;
    return _withDestination(HostRoutes.languagePath, uri);
  }
  if (atLanguage) return _safeDestination(uri.queryParameters['from']);

  // 2. Sessão: sem ela, só as telas do auth_module abrem, e o destino
  //    segue junto, como no idioma. Com ela, as telas de entrar não têm
  //    mais o que fazer, e o usuário segue para onde ia.
  final atAuth = uri.path.startsWith('${AuthRoutes.prefix}/');
  if (!authenticated) {
    if (atAuth) return null;
    return _withDestination(AuthRoutes.loginPath, uri);
  }
  if (atAuth) return _safeDestination(uri.queryParameters['from']);

  return null;
}

/// Leva a [path] com o destino original no parâmetro `from`.
String _withDestination(String path, Uri destination) => Uri(
  path: path,
  queryParameters: {'from': destination.toString()},
).toString();

/// Só caminhos internos: um `from` com esquema ou com `//` levaria a outro
/// host, e cai na tela inicial.
String _safeDestination(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return HostRoutes.homePath;
  }
  return from;
}
