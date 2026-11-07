import 'package:auth_module/domain/auth_failure.dart';
import 'package:auth_module/domain/value_objects/email_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza espaços e maiúsculas', () {
    expect(EmailAddress.parse('  Ana@Exemplo.com ').value, 'ana@exemplo.com');
  });

  test('recusa o que não tem formato de e-mail', () {
    for (final input in [
      'ana.exemplo.com',
      'ana@',
      '@exemplo.com',
      'a b@c.d',
    ]) {
      expect(
        () => EmailAddress.parse(input),
        throwsA(isA<InvalidEmailFailure>()),
        reason: input,
      );
    }
  });

  test('dois e-mails com o mesmo texto são o mesmo e-mail', () {
    expect(
      EmailAddress.parse('ana@exemplo.com'),
      EmailAddress.parse('ANA@exemplo.com'),
    );
  });
}
