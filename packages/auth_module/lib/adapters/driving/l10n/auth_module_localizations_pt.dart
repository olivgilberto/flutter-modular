// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'auth_module_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AuthModuleLocalizationsPt extends AuthModuleLocalizations {
  AuthModuleLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get loginTitle => 'Acesse sua conta';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Senha';

  @override
  String get showPassword => 'Mostrar senha';

  @override
  String get hidePassword => 'Esconder senha';

  @override
  String get loginSubmit => 'Entrar';

  @override
  String get loginCreateAccount => 'Criar uma conta';

  @override
  String get loginUnexpectedError =>
      'Não foi possível entrar agora. Tente de novo.';

  @override
  String get checkEmail => 'Confira o e-mail digitado.';

  @override
  String get loginInvalidCredentials => 'E-mail ou senha incorretos.';

  @override
  String get sessionExpiredMaybeChanges =>
      'Sua sessão expirou, e pode haver alterações ainda não enviadas. Entre de novo para enviar o que falta, ou descarte.';

  @override
  String sessionExpiredChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Sua sessão expirou, e há $count alterações ainda não enviadas. Entre de novo para enviar o que falta, ou descarte.',
      one:
          'Sua sessão expirou, e há 1 alteração ainda não enviada. Entre de novo para enviar o que falta, ou descarte.',
      zero: 'Sua sessão expirou. Entre de novo.',
    );
    return '$_temp0';
  }

  @override
  String get discardChanges => 'Descartar alterações';

  @override
  String get discardChangesTitle => 'Descartar alterações?';

  @override
  String get discardChangesMessage =>
      'O que foi feito sem conexão será apagado deste aparelho e não poderá ser enviado depois.';

  @override
  String get discard => 'Descartar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get registerTitle => 'Crie sua conta';

  @override
  String get nameLabel => 'Nome';

  @override
  String registerPasswordLabel(int minLength) {
    return 'Senha (pelo menos $minLength caracteres)';
  }

  @override
  String get registerSubmit => 'Criar conta';

  @override
  String get registerUnexpectedError =>
      'Não foi possível criar a conta agora. Tente de novo.';

  @override
  String registerWeakPassword(int minLength) {
    return 'Escolha outra senha: pelo menos $minLength caracteres, e que não seja uma senha conhecida.';
  }

  @override
  String get registerEmailTaken =>
      'Este e-mail já tem uma conta. Volte e entre com ele.';

  @override
  String get registerCheckData => 'Confira os dados e tente de novo.';

  @override
  String get logout => 'Sair';

  @override
  String get logoutTitle => 'Sair da conta?';

  @override
  String logoutLostChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count alterações feitas sem conexão ainda não foram enviadas e serão perdidas.',
      one:
          '1 alteração feita sem conexão ainda não foi enviada e será perdida.',
      zero: 'Nenhuma alteração feita sem conexão está esperando envio.',
    );
    return '$_temp0';
  }

  @override
  String get logoutCheckFailed =>
      'Não foi possível conferir se há alterações não enviadas. Se houver, elas serão perdidas.';

  @override
  String get logoutConfirm => 'Sair mesmo assim';
}
