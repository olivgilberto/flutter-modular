import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_module/adapters/driven/uuid_v4.dart';

/// Versão 4 no terceiro grupo; variante 10xx (8, 9, a ou b) no quarto.
final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('tem o formato de um UUID versão 4, com qualquer sorteio', () {
    for (var seed = 0; seed < 100; seed++) {
      expect(newUuidV4(Random(seed)), matches(_uuidV4));
    }
    expect(newUuidV4(), matches(_uuidV4));
  });

  test('não se repete', () {
    final ids = {for (var i = 0; i < 1000; i++) newUuidV4()};
    expect(ids, hasLength(1000));
  });
}
