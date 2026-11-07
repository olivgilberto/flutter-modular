import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/bootstrap/app_config.dart';
import 'package:mobile_tarefas_app/bootstrap/firebase_options.dart';

void main() {
  // Na cópia pública, nenhum flavor tem projeto do Firebase: o boot segue
  // sem ele. Depois do `flutterfire configure` (capítulo 38), este teste
  // volta a conferir o projectId de cada flavor, como no livro.
  test('sem os arquivos do Firebase, nenhum flavor tem opções', () {
    for (final flavor in Flavor.values) {
      expect(firebaseOptionsFor(flavor), isNull);
    }
  });
}
