import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/dev_backend_client.dart';
import 'support/journey.dart';

/// O fluxo offline do módulo de tarefas, no aparelho (capítulo 39): o
/// backend sai do ar pela porta de controle, a escrita fica no aparelho e
/// na fila, o aviso aparece, e a fila sobe sozinha quando ele volta. A
/// porta da API fecha de verdade: o app vê a conexão recusada, como diante
/// de um servidor fora do ar.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final backend = DevBackendClient();
  tearDownAll(() async {
    // Se o teste falhar no meio, o backend não fica fora do ar para o
    // próximo arquivo.
    await backend.start();
    backend.close();
  });

  testWidgets('sem servidor, a tarefa fica no aparelho e sobe quando ele '
      'volta', (tester) async {
    await backend.reset();
    await startApp(tester);
    await choosePortuguese(tester);
    await register(tester);

    await backend.stop();
    await createTask(tester, 'Ligar para o dentista');

    // O envio falha, o ConnectivityReportingApiClient pede uma conferência
    // e a sonda não alcança o servidor: o aviso do host (capítulo 35).
    await pumpUntil(tester, find.textContaining('Sem acesso ao servidor'));
    expect(taskTile('Ligar para o dentista'), findsOneWidget);

    await backend.start();
    // Ninguém toca em nada: a conferência seguinte do ConnectivityService,
    // de 15 s em diante, acha o servidor, e o SyncOrchestrator sobe a fila.
    await pumpUntilTrue(
      tester,
      () async => await backend.statusOf('Ligar para o dentista') == 'open',
      description: 'a tarefa feita sem servidor chegou a ele',
      timeout: const Duration(seconds: 90),
    );
    await pumpUntilGone(tester, find.textContaining('Sem acesso ao servidor'));
  });
}
