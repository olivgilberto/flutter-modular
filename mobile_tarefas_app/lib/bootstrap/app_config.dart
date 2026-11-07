import 'package:flutter/services.dart';

/// Os ambientes do app. O nome de cada um é o mesmo em três lugares: o
/// `--flavor` do Android e do iOS, o `main_[flavor].dart` e o
/// `config/[flavor].json`.
enum Flavor { dev, staging, prod }

/// Os valores que mudam entre ambientes (capítulo 10). Vêm do arquivo
/// passado com `--dart-define-from-file`; o código é o mesmo nos três.
final class AppConfig {
  const AppConfig({required this.flavor, required this.apiBaseUrl});

  /// Lê o ambiente do build. Só o `mainCommon` e o [AppConfig.forBackground]
  /// chamam.
  factory AppConfig.fromEnvironment(Flavor entryPoint) => AppConfig.resolve(
    entryPoint: entryPoint,
    nativeFlavor: appFlavor,
    defines: const {
      'FLAVOR': String.fromEnvironment('FLAVOR'),
      'API_BASE_URL': String.fromEnvironment('API_BASE_URL'),
    },
  );

  /// O ponto de entrada em segundo plano não tem `main_[flavor].dart`: o
  /// flavor é o do build, o mesmo do app, e passa pelas mesmas conferências
  /// (capítulo 32).
  factory AppConfig.forBackground() => AppConfig.fromEnvironment(
    Flavor.values.firstWhere(
      (flavor) => flavor.name == appFlavor,
      orElse: () => throw StateError('segundo plano sem --flavor.'),
    ),
  );

  /// Confere que as três fontes do flavor concordam e que os valores
  /// existem. Um build montado errado é um bug: falha na abertura, com a
  /// correção na mensagem, em vez de rodar contra o backend de outro
  /// ambiente.
  factory AppConfig.resolve({
    required Flavor entryPoint,
    required String? nativeFlavor,
    required Map<String, String> defines,
  }) {
    final name = entryPoint.name;
    if (nativeFlavor != name) {
      throw StateError(
        'main_$name.dart com --flavor ${nativeFlavor ?? '(nenhum)'}: '
        'use --flavor $name.',
      );
    }
    final configFlavor = defines['FLAVOR'] ?? '';
    if (configFlavor != name) {
      throw StateError(
        'main_$name.dart com FLAVOR "$configFlavor": '
        'use --dart-define-from-file=config/$name.json.',
      );
    }
    final apiBaseUrl = defines['API_BASE_URL'] ?? '';
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.scheme == 'https' || _isLocalDevBackend(entryPoint, uri))) {
      throw StateError(
        'API_BASE_URL inválida em config/$name.json: "$apiBaseUrl".',
      );
    }
    return AppConfig(flavor: entryPoint, apiBaseUrl: apiBaseUrl);
  }

  /// A única exceção ao https (capítulo 35): o backend de desenvolvimento
  /// de tools/dev_backend, no flavor dev e só na interface local, que o
  /// simulador do iOS compartilha com o computador e o emulador do Android
  /// alcança pelo `adb reverse`. Nada sai da máquina sem TLS.
  static bool _isLocalDevBackend(Flavor flavor, Uri uri) =>
      flavor == Flavor.dev &&
      uri.scheme == 'http' &&
      const {'127.0.0.1', 'localhost', '::1'}.contains(uri.host);

  final Flavor flavor;

  /// O endereço do backend: https, ou http na interface local no flavor dev.
  final String apiBaseUrl;
}
