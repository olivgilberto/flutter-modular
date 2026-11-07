import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'api_port.dart';

/// As rotas da porta de controle (capítulo 39): um teste de integração,
/// rodando no aparelho, tira a API do ar e a traz de volta sem ninguém no
/// terminal. A porta de controle é outra, porque a da API fecha de verdade.
///
/// - `POST /control/stop`: fecha a porta da API (conexões recusadas);
/// - `POST /control/start`: abre de novo, com o mesmo estado;
/// - `GET /control/status`: diz se a API está no ar.
///
/// As três respondem `{"open": true|false}`.
Handler controlHandler(ApiPort api, {void Function(String line)? log}) {
  Response status() => Response.ok(
    jsonEncode({'open': api.isOpen}),
    headers: {'content-type': 'application/json'},
  );

  final router = Router()
    ..post('/control/stop', (Request _) async {
      if (await api.close()) log?.call('controle: fora do ar');
      return status();
    })
    ..post('/control/start', (Request _) async {
      if (await api.open()) log?.call('controle: de volta');
      return status();
    })
    ..get('/control/status', (Request _) => status());
  return router.call;
}
