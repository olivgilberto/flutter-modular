import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/dev_backend_client.dart';
import 'support/journey.dart';

/// O caminho feliz, no aparelho, com tudo de verdade: o SQLCipher, o
/// armazenamento seguro, as preferências e o HTTP até o dev_backend
/// (capítulo 39). Nada aqui é simulado; o que o teste confere no servidor,
/// ele lê pelo GET /dev/state.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final backend = DevBackendClient();
  tearDownAll(backend.close);

  testWidgets('criar, concluir e arquivar chegam ao servidor, e o login '
      'seguinte traz a lista de lá', (tester) async {
    await backend.reset();
    await startApp(tester);

    await choosePortuguese(tester);
    final email = await register(tester);

    await createTask(tester, 'Comprar pão');
    await createTask(tester, 'Pagar a conta de luz');
    await pumpUntilTrue(
      tester,
      () async =>
          await backend.statusOf('Comprar pão') == 'open' &&
          await backend.statusOf('Pagar a conta de luz') == 'open',
      description: 'as duas tarefas abertas no servidor',
    );

    // Concluir: a caixa da linha.
    await tester.tap(
      find.descendant(
        of: taskTile('Comprar pão'),
        matching: find.byType(Checkbox),
      ),
    );
    await pumpUntilTrue(
      tester,
      () async => await backend.statusOf('Comprar pão') == 'done',
      description: '"Comprar pão" concluída no servidor',
    );

    // Arquivar: pela tela de edição, com a confirmação.
    await tester.tap(
      find.descendant(
        of: taskTile('Pagar a conta de luz'),
        matching: find.byTooltip('Editar'),
      ),
    );
    await pumpUntil(tester, find.text('Arquivar'));
    await tapVisible(tester, find.text('Arquivar'));
    await pumpUntil(tester, find.text('Arquivar tarefa?'));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Arquivar'),
      ),
    );
    await pumpUntilTrue(
      tester,
      () async => await backend.statusOf('Pagar a conta de luz') == 'archived',
      description: '"Pagar a conta de luz" arquivada no servidor',
    );
    await pumpUntil(tester, find.text('Tarefas'));

    // Sair: sem nada pendente, sem pergunta. O logout apaga os dados do
    // aparelho (capítulo 29).
    await tapVisible(tester, find.text('Sair'));
    await pumpUntil(tester, find.text('Acesse sua conta'));

    // Entrar de novo: a primeira lista vem do servidor.
    await tester.enterText(field('E-mail'), email);
    await tester.enterText(field('Senha'), password);
    await tapVisible(tester, find.text('Entrar'));
    // A concluída aparece: até o usuário escolher, a lista mostra as
    // concluídas, e o logout apagou a escolha com o resto dos dados.
    await pumpUntil(tester, taskTile('Comprar pão'));
    expect(find.byTooltip('Esconder concluídas'), findsOneWidget);

    expect(
      tester.widget<CheckboxListTile>(taskTile('Comprar pão')).value,
      isTrue,
    );
    expect(taskTile('Pagar a conta de luz'), findsNothing);
  });
}
