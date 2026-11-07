import 'package:adapter_http_http/adapter_http_http.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  HttpReachabilityProbe probeWith(Responder responder) => HttpReachabilityProbe(
    baseUrl: 'https://api.exemplo.com',
    path: '/health',
    client: FakeServer([responder]).client,
  );

  test('qualquer resposta HTTP conta como alcançável, mesmo 503', () async {
    expect(
      await probeWith((_) => json(503, '{}')).isBackendReachable(),
      isTrue,
    );
  });

  test('falha de transporte não conta', () async {
    expect(await probeWith(offline).isBackendReachable(), isFalse);
  });
}
