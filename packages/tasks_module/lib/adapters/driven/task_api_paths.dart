/// Os caminhos do backend de tarefas, todos a partir de uma versão. Nenhum
/// outro arquivo do módulo escreve um caminho.
abstract final class TaskApiPaths {
  static const version = '/v1';

  /// `GET` com `status=active`, `limit` e, a partir da segunda página,
  /// `cursor`. Responde `{"items": [...], "nextCursor": "..." | null}`.
  static const tasks = '$version/tasks';

  /// Uma tarefa: `PUT` cria, com o id gerado no app; `PATCH` altera ou
  /// arquiva, com a versão base. As duas respondem a tarefa com a versão
  /// nova (capítulo 32).
  static String task(String id) => '$tasks/${Uri.encodeComponent(id)}';
}
