import 'package:firebase_core/firebase_core.dart';

import 'app_config.dart';

/// As opções do Firebase de cada flavor.
///
/// Nesta cópia pública do livro, os arquivos `firebase_options_[flavor].dart`
/// não vêm no repositório: eles apontam para um projeto do Firebase, e cada
/// leitor cria o seu (capítulo 38). Sem eles, todo flavor devolve null, e o
/// boot segue sem o Firebase, com os adaptadores escrevendo no console
/// (capítulo 25).
///
/// Depois de rodar o `flutterfire configure` para cada flavor, troque o
/// corpo desta função pelo do livro:
///
/// ```dart
/// import '../firebase_options_dev.dart' as dev;
/// import '../firebase_options_prod.dart' as prod;
/// import '../firebase_options_staging.dart' as staging;
///
/// FirebaseOptions? firebaseOptionsFor(Flavor flavor) => switch (flavor) {
///   Flavor.dev => dev.DefaultFirebaseOptions.currentPlatform,
///   Flavor.staging => staging.DefaultFirebaseOptions.currentPlatform,
///   Flavor.prod => prod.DefaultFirebaseOptions.currentPlatform,
/// };
/// ```
FirebaseOptions? firebaseOptionsFor(Flavor flavor) => switch (flavor) {
  Flavor.dev || Flavor.staging || Flavor.prod => null,
};
