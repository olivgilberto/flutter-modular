import 'package:core/core.dart';
import 'package:http/http.dart' as http;

import 'io_client.dart';

/// [ReachabilityProbe] com o pacote http: um `HEAD` no endpoint de saúde do
/// backend, num cliente próprio, sem token nem nova tentativa e com tempo
/// curto. Qualquer resposta HTTP, mesmo 4xx ou 5xx, conta como alcançável;
/// só as falhas de transporte não contam.
final class HttpReachabilityProbe implements ReachabilityProbe {
  HttpReachabilityProbe({
    required String baseUrl,
    required this.path,
    Duration timeout = const Duration(seconds: 3),
    http.Client? client,
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _timeout = timeout,
       _client = client ?? ioClient(connectionTimeout: timeout);

  /// O endpoint de saúde: leve, sem autenticação e sem tocar no banco.
  final String path;
  final String _baseUrl;
  final Duration _timeout;
  final http.Client _client;

  @override
  Future<bool> isBackendReachable() async {
    try {
      await _client.head(Uri.parse('$_baseUrl$path')).timeout(_timeout);
      return true;
    } on Exception {
      return false;
    }
  }
}
