import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {required ThemeData theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: child),
);

void main() {
  for (final (mode, theme) in [
    ('claro', AppTheme.light),
    ('escuro', AppTheme.dark),
  ]) {
    testWidgets('o aviso de conexão aparece e é anunciado ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const AppConnectivityBanner(visible: true, message: 'Sem conexão'),
          theme: theme,
        ),
      );

      expect(find.text('Sem conexão'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Sem conexão')),
        isSemantics(label: 'Sem conexão', isLiveRegion: true),
      );
    });
  }

  testWidgets('escondido, o aviso não ocupa altura nem tem texto', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Align(
          alignment: Alignment.topCenter,
          child: AppConnectivityBanner(visible: false, message: 'Sem conexão'),
        ),
        theme: AppTheme.light,
      ),
    );

    expect(find.text('Sem conexão'), findsNothing);
    expect(tester.getSize(find.byType(AppConnectivityBanner)).height, 0);
  });

  testWidgets('o aviso tem pelo menos 48 dp de altura', (tester) async {
    await tester.pumpWidget(
      _app(
        const Align(
          alignment: Alignment.topCenter,
          child: AppConnectivityBanner(visible: true, message: 'Sem conexão'),
        ),
        theme: AppTheme.light,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(AppConnectivityBanner)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('o estado vazio mostra título e mensagem recebidos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nada por aqui',
          message: 'Crie a primeira tarefa',
        ),
        theme: AppTheme.dark,
      ),
    );

    expect(find.text('Nada por aqui'), findsOneWidget);
    expect(find.text('Crie a primeira tarefa'), findsOneWidget);
  });

  testWidgets('o placeholder de erro não tem texto', (tester) async {
    await tester.pumpWidget(const AppErrorPlaceholder());

    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
  });
}
