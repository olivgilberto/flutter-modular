import '../auth_failure.dart';

/// Uma senha que atende à política do produto, a da NIST SP 800-63B-4 para
/// senha como único fator: pelo menos 15 caracteres, contados como pontos
/// de código Unicode, e nenhuma regra de composição. A lista de senhas
/// comprometidas é verificada pelo backend.
final class Password {
  const Password._(this.value);

  /// Nunca remove espaços nem muda maiúsculas: a senha é exatamente o que
  /// o usuário digitou.
  factory Password.parse(String input) {
    final length = input.runes.length;
    if (length < minLength || length > maxLength) {
      throw const WeakPasswordFailure();
    }
    return Password._(input);
  }

  static const minLength = 15;

  /// A norma pede aceitar pelo menos 64; o limite existe para que ninguém
  /// envie um texto enorme ao backend.
  static const maxLength = 128;

  final String value;

  @override
  bool operator ==(Object other) => other is Password && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Nunca o valor: um `Password` impresso num log não pode vazar a senha.
  @override
  String toString() => 'Password(***)';
}
