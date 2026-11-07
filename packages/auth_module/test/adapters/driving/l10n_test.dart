import 'dart:convert';
import 'dart:io';

import 'package:auth_module/adapters/driving/bloc/login_bloc.dart';
import 'package:auth_module/adapters/driving/l10n/auth_module_localizations.dart';
import 'package:auth_module/adapters/driving/session/session_bloc.dart';
import 'package:auth_module/adapters/driving/views/login_view.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'driving_mocks.dart';

/// As traduções do módulo (capítulo 37). Uma chave que falta numa tradução
/// não é erro para o gen-l10n: a tela mostra o texto do template, em
/// inglês, para quem escolheu português. Este teste transforma o aviso em
/// falha.
void main() {
  const arbDir = 'lib/adapters/driving/l10n';
  const template = 'auth_module_en.arb';

  Map<String, Object?> read(String name) =>
      jsonDecode(File('$arbDir/$name').readAsStringSync())
          as Map<String, Object?>;

  Set<String> messages(Map<String, Object?> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  final translations = [
    for (final file in Directory(arbDir).listSync().whereType<File>())
      if (file.path.endsWith('.arb')) file.uri.pathSegments.last,
  ]..sort();

  test('há o template e pelo menos uma tradução', () {
    expect(translations, containsAll([template, 'auth_module_pt.arb']));
  });

  test('toda tradução tem exatamente as chaves do template', () {
    final expected = messages(read(template));
    for (final name in translations) {
      final arb = read(name);
      expect(messages(arb), expected, reason: name);
      // O idioma declarado no arquivo é o do nome dele.
      expect(
        name,
        'auth_module_${arb['@@locale']}.arb',
        reason: 'o @@locale de $name',
      );
    }
  });

  test('a classe gerada atende a todo idioma de algum ARB', () {
    for (final name in translations) {
      final tag = name.substring('auth_module_'.length, name.length - 4);
      expect(
        AuthModuleLocalizations.delegate.isSupported(Locale(tag)),
        isTrue,
        reason: tag,
      );
    }
  });

  test('todo plural tem o caso =0: em português, a categoria "one" vale '
      'para 0 e para 1', () {
    final pt = lookupAuthModuleLocalizations(const Locale('pt', 'BR'));
    expect(pt.logoutLostChanges(0), startsWith('Nenhuma alteração'));
    expect(pt.sessionExpiredChanges(0), 'Sua sessão expirou. Entre de novo.');
    expect(pt.logoutLostChanges(1), startsWith('1 alteração'));
  });

  group('a tela de login em cada idioma', () {
    late MockLoginBloc bloc;

    setUp(() {
      bloc = MockLoginBloc();
      whenListen(
        bloc,
        const Stream<LoginState>.empty(),
        initialState: const LoginInitial(),
      );
    });

    Future<void> show(WidgetTester tester, Locale locale, int pending) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: locale,
            localizationsDelegates:
                AuthModuleLocalizations.localizationsDelegates,
            supportedLocales: AuthModuleLocalizations.supportedLocales,
            home: BlocProvider<LoginBloc>.value(
              value: bloc,
              child: LoginView(
                expiredSession: SessionExpiredWithPendingChanges(
                  pendingChanges: pending,
                ),
              ),
            ),
          ),
        );

    testWidgets('inglês, o idioma do template, com o plural de uma '
        'alteração', (tester) async {
      await show(tester, const Locale('en'), 1);

      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(find.textContaining('there is 1 change'), findsOneWidget);
      // Os textos internos do Material também mudam: o delegate global
      // vem na lista da classe gerada.
      final material = MaterialLocalizations.of(
        tester.element(find.byType(LoginView)),
      );
      expect(material.cancelButtonLabel, 'Cancel');
    });

    testWidgets('português do Brasil, que cai no ARB "pt", com o plural de '
        'várias', (tester) async {
      await show(tester, const Locale('pt', 'BR'), 3);

      expect(find.text('Acesse sua conta'), findsOneWidget);
      expect(find.textContaining('há 3 alterações'), findsOneWidget);
    });
  });
}
