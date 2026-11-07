import 'dart:convert';
import 'dart:io';

import 'package:dev_backend/dev_backend.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// `dart run tools/dev_backend/bin/dev_backend.dart [--port 8080]
/// [--token-minutes 15] [--control-port 8081]`, a partir da raiz do
/// workspace (capítulo 35). Escuta só na interface local: nada fora desta
/// máquina o alcança.
///
/// No terminal, `parar` fecha a porta sem perder o estado, como um backend
/// fora do ar, e `voltar` abre de novo. Com `--control-port`, as mesmas
/// duas ações também chegam por HTTP, numa porta à parte, para os testes
/// de integração do capítulo 39.
Future<void> main(List<String> args) async {
  final port = _option(args, '--port') ?? 8080;
  final tokenMinutes = _option(args, '--token-minutes') ?? 15;
  final controlPort = _option(args, '--control-port');
  final state = DevBackendState(tokenTtl: Duration(minutes: tokenMinutes));
  void log(String line) => stdout.writeln(_stamp(line));
  final api = ApiPort(devBackendHandler(state, log: log), port);
  await api.open();
  stdout
    ..writeln('dev_backend em http://127.0.0.1:$port')
    ..writeln('Tudo em memória: encerrar o processo apaga contas e tarefas.')
    ..writeln(
      'Digite "parar" para tirar o backend do ar e "voltar" para '
      'trazê-lo de volta, com o mesmo estado.',
    )
    ..writeln(
      'Rotas de "outra pessoa": GET /dev/state, '
      'POST /dev/tasks/<id>/edit, DELETE /dev/tasks/<id>, '
      'POST /dev/reject-next, POST /dev/omit-version-next, '
      'POST /dev/expire-tokens, POST /dev/reset',
    );
  if (controlPort != null) {
    await shelf_io.serve(
      controlHandler(api, log: log),
      InternetAddress.loopbackIPv4,
      controlPort,
    );
    stdout.writeln(
      'controle em http://127.0.0.1:$controlPort: POST /control/stop, '
      'POST /control/start, GET /control/status',
    );
  }

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    switch (line.trim()) {
      case 'parar' when api.isOpen:
        await api.close();
        log('fora do ar: conexões recusadas');
      case 'voltar' when !api.isOpen:
        await api.open();
        log('de volta em http://127.0.0.1:$port');
      case '':
        break;
      default:
        stdout.writeln('Comandos: parar, voltar.');
    }
  }
}

int? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  return int.tryParse(args[index + 1]);
}

String _stamp(String line) {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(now.hour)}:${two(now.minute)}:${two(now.second)} $line';
}
