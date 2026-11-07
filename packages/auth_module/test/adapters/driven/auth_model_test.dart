import 'dart:convert';
import 'dart:io';

import 'package:auth_module/adapters/driven/models/auth_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aceita a resposta de exemplo da documentação da API', () {
    final json = jsonDecode(
      File('test/fixtures/sign_in_response.json').readAsStringSync(),
    );

    final model = AuthModel.fromJson(json);

    expect(model.userId, 'u-1');
    expect(model.email, 'ana@exemplo.com');
    expect(model.refreshToken, 'rt-1');
  });

  test('recusa uma resposta sem o token de renovação', () {
    expect(
      () => AuthModel.fromJson({
        'user': {'id': 'u-1', 'name': 'Ana', 'email': 'ana@exemplo.com'},
        'accessToken': 'at-1',
      }),
      throwsFormatException,
    );
  });

  test('ida e volta pela linha do banco', () {
    const model = AuthModel(
      userId: 'u-1',
      name: 'Ana',
      email: 'ana@exemplo.com',
      accessToken: 'at-1',
      refreshToken: 'rt-1',
    );

    final back = AuthModel.fromMap(model.toMap());

    expect(back.toMap(), model.toMap());
  });
}
