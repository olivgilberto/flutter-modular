import 'package:auth_module/domain/entities/user.dart';
import 'package:auth_module/domain/value_objects/email_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ana = User(
    id: 'u-1',
    name: 'Ana',
    email: EmailAddress.parse('ana@exemplo.com'),
  );

  test('igualdade pelo id', () {
    expect(ana.rename('Ana Souza'), ana);
  });

  test('renomear cria outro objeto com o mesmo id e e-mail', () {
    final renamed = ana.rename('Ana Souza');

    expect(renamed.name, 'Ana Souza');
    expect(renamed.email, ana.email);
    expect(ana.name, 'Ana');
  });
}
