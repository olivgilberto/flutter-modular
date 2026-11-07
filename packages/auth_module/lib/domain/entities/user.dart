import '../value_objects/email_address.dart';

/// O usuário da sessão. Igualdade pelo id: o mesmo usuário continua o
/// mesmo depois de trocar de nome.
final class User {
  const User({required this.id, required this.name, required this.email});

  /// Opaco, gerado pelo backend. É também o identificador que o
  /// `AppLogger` recebe, nunca o e-mail.
  final String id;
  final String name;
  final EmailAddress email;

  User rename(String newName) => User(id: id, name: newName, email: email);

  @override
  bool operator ==(Object other) => other is User && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
