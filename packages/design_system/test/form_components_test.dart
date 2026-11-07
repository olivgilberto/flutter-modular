import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('o campo de senha esconde o texto e o botão diz o que faz', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'cavalo-bateria-grampo');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        AppTextField.password(
          controller: controller,
          label: 'Senha',
          showLabel: 'Mostrar senha',
          hideLabel: 'Esconder senha',
        ),
      ),
    );

    TextField field() => tester.widget<TextField>(find.byType(TextField));
    expect(field().obscureText, isTrue);
    expect(field().enableSuggestions, isFalse);
    expect(find.byTooltip('Mostrar senha'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();

    expect(field().obscureText, isFalse);
    expect(find.byTooltip('Esconder senha'), findsOneWidget);
  });

  testWidgets('carregando, o botão principal fica desabilitado e mantém o '
      'rótulo', (tester) async {
    await tester.pumpWidget(
      _app(AppPrimaryButton(label: 'Entrar', loading: true, onPressed: () {})),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('o erro dentro da tela é anunciado', (tester) async {
    await tester.pumpWidget(
      _app(const AppInlineError(message: 'E-mail ou senha incorretos.')),
    );

    expect(
      tester.getSemantics(find.text('E-mail ou senha incorretos.')),
      isSemantics(label: 'E-mail ou senha incorretos.', isLiveRegion: true),
    );
  });

  testWidgets('num tablet, o formulário não passa da largura compact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppForm(
          title: 'Acesse sua conta',
          children: [AppTextButton(label: 'Criar uma conta', onPressed: () {})],
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(TextButton)).width,
      AppBreakpoints.compactMaxWidth,
    );
  });
}
