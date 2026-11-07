// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mobile_tarefas_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class MobileTarefasLocalizationsPt extends MobileTarefasLocalizations {
  MobileTarefasLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Tarefas';

  @override
  String get connectivityOffline =>
      'Sem conexão. O que você fizer fica guardado e é enviado quando a conexão voltar.';

  @override
  String get connectivityNoInternet =>
      'Sem acesso ao servidor. O que você fizer fica guardado e é enviado assim que ele responder.';

  @override
  String get deviceIntegrityWarning =>
      'Este aparelho parece ter root ou jailbreak. O app continua funcionando, mas os dados guardados nele ficam menos protegidos.';

  @override
  String get deviceIntegrityDismiss => 'Entendi';
}
