import '../auth_failure.dart';

/// Um e-mail que só existe se tiver o formato de um e-mail. A validação é
/// permissiva de propósito: a confirmação de verdade é a mensagem que o
/// backend envia para o endereço.
final class EmailAddress {
  const EmailAddress._(this.value);

  /// Remove espaços nas pontas e passa para minúsculas, uma regra de
  /// negócio combinada com o backend.
  factory EmailAddress.parse(String input) {
    final normalized = input.trim().toLowerCase();
    if (!_pattern.hasMatch(normalized)) throw const InvalidEmailFailure();
    return EmailAddress._(normalized);
  }

  static final _pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is EmailAddress && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
