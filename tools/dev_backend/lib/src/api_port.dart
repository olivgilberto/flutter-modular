import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// A porta da API, que fecha e abre de novo sem perder o estado: um backend
/// fora do ar, do ponto de vista do app, recusa conexões (capítulo 35). O
/// `parar`/`voltar` do terminal e a porta de controle do capítulo 39 usam a
/// mesma peça.
final class ApiPort {
  ApiPort(this._handler, this.port);

  final Handler _handler;

  /// A porta, sempre na interface local.
  final int port;

  HttpServer? _server;

  bool get isOpen => _server != null;

  /// Abre a porta. Devolve `false` se ela já estava aberta.
  Future<bool> open() async {
    if (_server != null) return false;
    _server = await shelf_io.serve(
      _handler,
      InternetAddress.loopbackIPv4,
      port,
    );
    return true;
  }

  /// Fecha a porta e derruba as conexões abertas. Devolve `false` se ela já
  /// estava fechada.
  Future<bool> close() async {
    final server = _server;
    if (server == null) return false;
    _server = null;
    await server.close(force: true);
    return true;
  }
}
