import 'package:core/core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Uma resposta do servidor simulado, montada a cada requisição.
typedef Responder = http.Response Function(http.Request request);

http.Response json(int status, String body) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

Never offline(http.Request request) =>
    throw http.ClientException('sem rede', request.url);

/// Troca a rede do pacote http: cada requisição consome o próximo
/// [Responder]; o último se repete. Cada tentativa chega aqui como uma
/// requisição nova, com os cabeçalhos com que saiu.
final class FakeServer {
  FakeServer(this._responders);

  final List<Responder> _responders;
  final requests = <http.Request>[];

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    final responder = _responders.length > 1
        ? _responders.removeAt(0)
        : _responders.single;
    return responder(request);
  });
}

final class FakeLogger implements AppLogger {
  final messages = <String>[];

  @override
  void log(String message) => messages.add(message);

  @override
  void error(String reason, Object error, StackTrace stackTrace) {}

  @override
  void fatal(Object error, StackTrace stackTrace) {}

  @override
  void setUserId(String? opaqueId) {}
}

/// A sessão vista pelo adaptador: o token atual e o resultado da
/// renovação, que pode ser um token novo, `null` (sessão encerrada) ou um
/// erro (sem rede para renovar).
final class FakeTokenProvider implements TokenProvider {
  FakeTokenProvider(this.token, {this.refreshed, this.refreshError});

  String? token;
  final String? refreshed;
  final Exception? refreshError;
  var refreshCalls = 0;

  @override
  Future<String?> currentToken() async => token;

  @override
  Future<String?> refreshToken() async {
    refreshCalls++;
    if (refreshError case final error?) throw error;
    return token = refreshed;
  }
}
