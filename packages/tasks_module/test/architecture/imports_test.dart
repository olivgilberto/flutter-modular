import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// O que o módulo de tarefas importa, lido dos próprios arquivos
/// (capítulo 36). O `check-deps` confere o `pubspec.yaml`, e o
/// `depend_on_referenced_packages` impede importar o que ele não declara;
/// este teste confere o que cada camada usa do que foi declarado. O plugin
/// do analisador do capítulo 40 generaliza as regras para todos os módulos.
void main() {
  final files = _sources();

  test('lê os arquivos do módulo', () {
    expect(files.keys, contains('tasks_module.dart'));
    expect(files.length, greaterThan(30));
  });

  test('cada camada importa só os pacotes que lhe cabem', () {
    const allowed = {
      'domain': {'core'},
      // Capítulo 38: o caso de uso recebe o AppAnalytics, porta do core.
      'application': {'core'},
      'adapters/driven': {'core'},
      // Capítulo 37: as traduções. A classe gerada pelo gen-l10n importa o
      // flutter_localizations e o intl, e mora no lado driving.
      'adapters/driving': {
        'core',
        'design_system',
        'flutter',
        'flutter_bloc',
        'bloc_concurrency',
        'go_router',
        'get_it',
        'flutter_localizations',
        'intl',
      },
      'entrada': {'core', 'get_it'},
    };
    final found = <String>[];
    files.forEach((path, imports) {
      final layer = _layerOf(path);
      for (final uri in imports.where((u) => u.startsWith('package:'))) {
        final package = uri.substring('package:'.length).split('/').first;
        if (!allowed[layer]!.contains(package)) found.add('$path → $uri');
      }
    });
    expect(found, isEmpty);
  });

  test('nenhuma tecnologia que o core abstrai, nenhum outro módulo, nenhum '
      'adaptador', () {
    final everything = files.values.expand((imports) => imports).toSet();
    final forbidden = everything.where(
      (uri) =>
          uri.startsWith('package:auth_module/') ||
          uri.startsWith('package:adapter_') ||
          uri.startsWith('package:dio/') ||
          uri.startsWith('package:sqflite') ||
          uri.startsWith('package:flutter_secure_storage/') ||
          uri.startsWith('package:path_provider/') ||
          uri.startsWith('package:workmanager/') ||
          uri.startsWith('package:shared_preferences/') ||
          uri.startsWith('package:connectivity_plus/') ||
          uri.startsWith('package:firebase_') ||
          uri.startsWith('package:http/'),
    );
    expect(forbidden, isEmpty);
  });

  test('o domínio e a aplicação não conhecem o Flutter nem o dart:io', () {
    final found = [
      for (final MapEntry(key: path, value: imports) in files.entries)
        if (_layerOf(path) == 'domain' || _layerOf(path) == 'application')
          for (final uri in imports)
            if (uri.startsWith('package:flutter') || uri == 'dart:io')
              '$path → $uri',
    ];
    expect(found, isEmpty);
  });

  test('as camadas apontam para dentro, e os dois lados não se veem', () {
    // Quem cada camada pode importar dentro do próprio módulo.
    const inward = {
      'domain': {'domain'},
      'application': {'domain', 'application'},
      'adapters/driven': {'domain', 'application', 'adapters/driven'},
      'adapters/driving': {'domain', 'application', 'adapters/driving'},
      'entrada': {
        'domain',
        'application',
        'adapters/driven',
        'adapters/driving',
      },
    };
    final found = <String>[];
    files.forEach((path, imports) {
      final from = _layerOf(path);
      for (final uri in imports.where((u) => !u.contains(':'))) {
        final target = _layerOf(_resolve(path, uri));
        if (!inward[from]!.contains(target)) found.add('$path → $uri');
      }
    });
    expect(found, isEmpty);
  });

  test('o get_it só aparece na borda: o arquivo de entrada e as '
      'Pages', () {
    final found = [
      for (final MapEntry(key: path, value: imports) in files.entries)
        if (imports.contains('package:get_it/get_it.dart') &&
            path != 'tasks_module.dart' &&
            !path.startsWith('adapters/driving/pages/'))
          path,
    ];
    expect(found, isEmpty);
  });
}

/// Cada arquivo de lib/, pelo caminho relativo, com os imports, exports e
/// parts que ele declara.
Map<String, List<String>> _sources() {
  final root = Directory('lib');
  // A linha da diretiva basta: um `show` na linha seguinte não muda o alvo.
  final directive = RegExp(r"^(?:import|export|part)\s+'([^']+)'");
  return {
    for (final file in root.listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart'))
        file.path.substring('lib/'.length).replaceAll(r'\', '/'): [
          for (final line in file.readAsLinesSync())
            if (directive.firstMatch(line.trim()) case final match?)
              match.group(1)!,
        ],
  };
}

String _layerOf(String path) {
  for (final layer in [
    'domain',
    'application',
    'adapters/driven',
    'adapters/driving',
  ]) {
    if (path.startsWith('$layer/')) return layer;
  }
  return 'entrada';
}

/// O caminho, relativo a lib/, de um import relativo.
String _resolve(String from, String uri) {
  final parts = from.split('/')..removeLast();
  for (final segment in uri.split('/')) {
    if (segment == '..') {
      parts.removeLast();
    } else if (segment != '.') {
      parts.add(segment);
    }
  }
  return parts.join('/');
}
