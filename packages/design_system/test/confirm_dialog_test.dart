import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Abre o diálogo por um botão e guarda a resposta.
  Future<List<bool>> open(WidgetTester tester) async {
    final answers = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => answers.add(
                await showAppConfirmDialog(
                  context,
                  title: 'Sair da conta?',
                  message: 'Duas alterações ainda não foram enviadas.',
                  confirmLabel: 'Sair mesmo assim',
                  cancelLabel: 'Cancelar',
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return answers;
  }

  testWidgets('confirmar devolve true', (tester) async {
    final answers = await open(tester);
    expect(
      find.text('Duas alterações ainda não foram enviadas.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Sair mesmo assim'));
    await tester.pumpAndSettle();

    expect(answers, [true]);
  });

  testWidgets('cancelar ou tocar fora devolve false', (tester) async {
    final answers = await open(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(answers, [false, false]);
  });

  // Capítulo 39: a fonte do sistema em 3,0, num telefone pequeno (375 × 667
  // pontos), com uma mensagem do tamanho das que os módulos mandam. Sem
  // rolagem, o diálogo transbordava.
  testWidgets('com a fonte do sistema em 3,0, o diálogo rola e os dois '
      'botões se alcançam', (tester) async {
    tester.view
      ..physicalSize = const Size(750, 1334)
      ..devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppConfirmDialog(
                context,
                title: 'Sair da conta?',
                message:
                    '2 alterações feitas sem conexão ainda não foram '
                    'enviadas e serão perdidas.',
                confirmLabel: 'Sair mesmo assim',
                cancelLabel: 'Cancelar',
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final label in ['Sair mesmo assim', 'Cancelar']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.text(label));
      expect(rect.top, greaterThanOrEqualTo(0), reason: label);
      expect(rect.bottom, lessThanOrEqualTo(667), reason: label);
    }
  });
}
