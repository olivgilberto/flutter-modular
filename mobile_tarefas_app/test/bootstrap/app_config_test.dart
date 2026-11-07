import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/bootstrap/app_config.dart';

const _url = 'https://api.dev.mobiletarefas.example';

Matcher _stateError(String hint) => throwsA(
  isA<StateError>().having((e) => e.message, 'message', contains(hint)),
);

void main() {
  test('as três fontes do flavor concordam: o app recebe os valores do '
      'arquivo', () {
    final config = AppConfig.resolve(
      entryPoint: Flavor.dev,
      nativeFlavor: 'dev',
      defines: {'FLAVOR': 'dev', 'API_BASE_URL': _url},
    );

    expect(config.flavor, Flavor.dev);
    expect(config.apiBaseUrl, _url);
  });

  test('sem --flavor, ou com o de outro ambiente, o app não abre', () {
    for (final nativeFlavor in [null, 'prod']) {
      expect(
        () => AppConfig.resolve(
          entryPoint: Flavor.dev,
          nativeFlavor: nativeFlavor,
          defines: {'FLAVOR': 'dev', 'API_BASE_URL': _url},
        ),
        _stateError('use --flavor dev'),
      );
    }
  });

  test('com o arquivo de outro ambiente, ou sem arquivo, o app não abre', () {
    for (final defines in [
      {'FLAVOR': 'prod', 'API_BASE_URL': 'https://api.mobiletarefas.example'},
      <String, String>{},
    ]) {
      expect(
        () => AppConfig.resolve(
          entryPoint: Flavor.dev,
          nativeFlavor: 'dev',
          defines: defines,
        ),
        _stateError('--dart-define-from-file=config/dev.json'),
      );
    }
  });

  test('sem endereço do backend, ou sem https, o app não abre', () {
    for (final url in ['', 'http://api.dev.mobiletarefas.example', 'api']) {
      expect(
        () => AppConfig.resolve(
          entryPoint: Flavor.dev,
          nativeFlavor: 'dev',
          defines: {'FLAVOR': 'dev', 'API_BASE_URL': url},
        ),
        _stateError('API_BASE_URL inválida'),
      );
    }
  });

  test('o backend local de desenvolvimento aceita http, só no dev e só na '
      'interface local (capítulo 35)', () {
    for (final url in ['http://127.0.0.1:8080', 'http://localhost:8080']) {
      final config = AppConfig.resolve(
        entryPoint: Flavor.dev,
        nativeFlavor: 'dev',
        defines: {'FLAVOR': 'dev', 'API_BASE_URL': url},
      );
      expect(config.apiBaseUrl, url);
    }
    // Fora da máquina, ou fora do dev, continua sendo https ou nada.
    for (final (flavor, url) in [
      (Flavor.dev, 'http://192.168.0.10:8080'),
      (Flavor.dev, 'http://127.0.0.1.example:8080'),
      (Flavor.staging, 'http://127.0.0.1:8080'),
      (Flavor.prod, 'http://localhost:8080'),
    ]) {
      expect(
        () => AppConfig.resolve(
          entryPoint: flavor,
          nativeFlavor: flavor.name,
          defines: {'FLAVOR': flavor.name, 'API_BASE_URL': url},
        ),
        _stateError('API_BASE_URL inválida'),
        reason: url,
      );
    }
  });

  test('o config/dev_local.json aponta o dev para o backend local', () {
    final json = File('config/dev_local.json').readAsStringSync();
    final defines = (jsonDecode(json) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );

    final config = AppConfig.resolve(
      entryPoint: Flavor.dev,
      nativeFlavor: 'dev',
      defines: defines,
    );
    expect(config.apiBaseUrl, 'http://127.0.0.1:8080');
  });

  test('cada flavor tem um arquivo de configuração válido e um ponto de '
      'entrada', () {
    for (final flavor in Flavor.values) {
      final json = File('config/${flavor.name}.json').readAsStringSync();
      final defines = (jsonDecode(json) as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );

      final config = AppConfig.resolve(
        entryPoint: flavor,
        nativeFlavor: flavor.name,
        defines: defines,
      );

      expect(config.flavor, flavor);
      expect(
        File('lib/main_${flavor.name}.dart').readAsStringSync(),
        contains('mainCommon(Flavor.${flavor.name})'),
      );
    }
  });
}
