import 'dart:convert';
import 'dart:io';

/// O dev_backend visto do aparelho (capítulos 35 e 39): a porta da API,
/// para ler e limpar o estado, e a porta de controle, para tirar a API do
/// ar e trazê-la de volta. No simulador do iOS, o 127.0.0.1 é o do Mac; no
/// emulador do Android, o script de integração liga as duas portas com o
/// adb reverse.
final class DevBackendClient {
  DevBackendClient({
    this.api = 'http://127.0.0.1:8080',
    this.control = 'http://127.0.0.1:8081',
  });

  final String api;
  final String control;
  final HttpClient _http = HttpClient();

  /// Apaga contas, sessões e tarefas: cada teste começa do zero.
  Future<void> reset() => _send('POST', '$api/dev/reset');

  /// Fecha a porta da API: o app passa a ver conexões recusadas.
  Future<void> stop() => _send('POST', '$control/control/stop');

  /// Abre a porta da API de novo, com o mesmo estado.
  Future<void> start() => _send('POST', '$control/control/start');

  /// As tarefas que o servidor guarda, de qualquer usuário.
  Future<List<Map<String, Object?>>> tasks() async {
    final body = await _send('GET', '$api/dev/state');
    final state = jsonDecode(body) as Map<String, Object?>;
    return (state['tasks']! as List).cast<Map<String, Object?>>();
  }

  /// O status, no servidor, da tarefa com esse título; `null` se ela não
  /// chegou lá.
  Future<String?> statusOf(String title) async {
    for (final task in await tasks()) {
      if (task['title'] == title) return task['status'] as String?;
    }
    return null;
  }

  void close() => _http.close(force: true);

  Future<String> _send(String method, String url) async {
    final request = await _http.openUrl(method, Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 300) {
      throw HttpException('$method $url → ${response.statusCode}: $body');
    }
    return body;
  }
}
