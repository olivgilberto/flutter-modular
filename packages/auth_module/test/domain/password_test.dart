import 'package:auth_module/domain/auth_failure.dart';
import 'package:auth_module/domain/value_objects/password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aceita 15 caracteres sem nenhuma regra de composição', () {
    expect(Password.parse('cavalobateriagr').value, hasLength(15));
  });

  test('recusa menos de 15 caracteres', () {
    expect(
      () => Password.parse('cavalobateriag'),
      throwsA(isA<WeakPasswordFailure>()),
    );
  });

  test('conta pontos de código, não unidades UTF-16', () {
    // Sete emojis são 14 unidades UTF-16, mas só 7 caracteres.
    expect(
      () => Password.parse('🐴🔋📎🐴🔋📎🐴'),
      throwsA(isA<WeakPasswordFailure>()),
    );
    expect(
      Password.parse('🐴🔋📎🐴🔋📎🐴🔋📎🐴🔋📎🐴🔋📎').value.runes,
      hasLength(15),
    );
  });

  test('guarda a senha como foi digitada, espaços incluídos', () {
    expect(Password.parse(' cavalo bateria ').value, ' cavalo bateria ');
  });

  test('recusa mais de 128 caracteres', () {
    expect(
      () => Password.parse('a' * 129),
      throwsA(isA<WeakPasswordFailure>()),
    );
  });

  test('nunca aparece num log', () {
    final password = Password.parse('cavalo-bateria-grampo');

    expect('$password', isNot(contains('cavalo')));
  });
}
