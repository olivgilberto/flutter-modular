import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/bootstrap/app_config.dart';
import 'package:mobile_tarefas_app/main_common.dart';

// Os passos que os testes de integração repetem (capítulo 39). Cada
// arquivo de integration_test/ roda num app instalado do zero: o script
// desinstala o app antes de cada um, e cada teste limpa o dev_backend.

/// O app inteiro, como o main_dev.dart o monta, com as três exceções de
/// teste do mainCommon: sem Firebase, sem os handlers globais e sem o
/// pedido de rastreamento.
Future<void> startApp(WidgetTester tester) async {
  await mainCommon(
    Flavor.dev,
    withFirebase: false,
    withErrorHandlers: false,
    withTrackingRequest: false,
  );
  await tester.pump();
}

/// Bombeia quadros até [finder] achar alguma coisa. O pumpAndSettle não
/// serve aqui: com a rede e o banco de verdade, há sempre um indicador
/// girando ou um temporizador vivo, e ele esperaria para sempre.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) => _pumpWhile(
  tester,
  () => finder.evaluate().isEmpty,
  'não apareceu: $finder',
  timeout,
);

/// O contrário: bombeia até [finder] não achar mais nada.
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) => _pumpWhile(
  tester,
  () => finder.evaluate().isNotEmpty,
  'não sumiu: $finder',
  timeout,
);

Future<void> _pumpWhile(
  WidgetTester tester,
  bool Function() waiting,
  String failure,
  Duration timeout,
) async {
  final end = DateTime.now().add(timeout);
  while (waiting()) {
    if (DateTime.now().isAfter(end)) {
      fail('em ${timeout.inSeconds} s, $failure');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Bombeia quadros até [condition] ser verdadeira. Para o que só o
/// servidor sabe, como uma tarefa que chegou lá.
Future<void> pumpUntilTrue(
  WidgetTester tester,
  Future<bool> Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('em ${timeout.inSeconds} s, não aconteceu: $description');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// A primeira abertura: o idioma, e a tela de login.
Future<void> choosePortuguese(WidgetTester tester) async {
  await pumpUntil(tester, find.text('Português (Brasil)'));
  await tester.tap(find.text('Português (Brasil)'));
  await pumpUntil(tester, find.text('Acesse sua conta'));
}

/// Cria uma conta com um e-mail que nenhum teste anterior usou e espera a
/// lista de tarefas, vazia.
Future<String> register(WidgetTester tester) async {
  final email = 'ana.${DateTime.now().millisecondsSinceEpoch}@exemplo.com';
  await tapVisible(tester, find.text('Criar uma conta'));
  await pumpUntil(tester, find.text('Crie sua conta'));
  await tester.enterText(field('Nome'), 'Ana');
  await tester.enterText(field('E-mail'), email);
  await tester.enterText(field('Senha (pelo menos'), password);
  await tapVisible(tester, find.text('Criar conta'));
  await pumpUntil(tester, find.text('Nenhuma tarefa por aqui'));
  return email;
}

/// Uma senha que passa na política do capítulo 20.
const password = 'cavalo-bateria-grampo';

/// Escreve uma tarefa no campo do topo da lista e toca em "Adicionar".
Future<void> createTask(WidgetTester tester, String title) async {
  await tester.enterText(field('Nova tarefa'), title);
  await tester.tap(find.byTooltip('Adicionar'));
  await pumpUntil(tester, taskTile(title));
}

/// A linha da lista com a tarefa [title]. Não o texto solto: o campo do
/// topo também pode estar mostrando o mesmo título.
Finder taskTile(String title) => find.widgetWithText(CheckboxListTile, title);

/// Rola até [finder] e toca nele: com o teclado aberto, o botão de um
/// formulário pode estar fora da tela, e o toque cairia em outro lugar.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

/// O campo de texto cujo rótulo começa com [label].
Finder field(String label) => find.ancestor(
  of: find.textContaining(label),
  matching: find.byType(TextField),
);
