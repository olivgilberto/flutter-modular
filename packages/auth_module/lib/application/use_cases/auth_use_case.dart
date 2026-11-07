import 'dart:async';

import 'package:core/core.dart';

import '../../domain/entities/user.dart';
import '../../domain/value_objects/email_address.dart';
import '../../domain/value_objects/password.dart';
import '../ports/auth_repository.dart';
import '../ports/data_owner_repository.dart';

/// A porta driving da autenticação: um caso de uso para a feature inteira.
/// Recebe texto cru da tela e só entrega value objects válidos à porta.
///
/// Não é `final`: os testes do Bloc (capítulo 22) o simulam com
/// `implements`, o que um `final class` proibiria fora deste arquivo.
class AuthUseCase {
  AuthUseCase({
    required AuthRepository repository,
    required DataOwnerRepository owner,
    required LogoutCleanerRegistry cleaners,
    required OutboxRegistry outboxes,
    required AppLogger logger,
    required AppAnalytics analytics,
  }) : _repository = repository,
       _owner = owner,
       _cleaners = cleaners,
       _outboxes = outboxes,
       _logger = logger,
       _analytics = analytics;

  final AuthRepository _repository;

  /// O dono dos dados que os módulos guardam no aparelho. Uma sessão que
  /// expirou com alterações não enviadas ainda não apagou esses dados, e o
  /// dono continua gravado até eles saírem, mesmo depois de um reinício
  /// (capítulos 29 e 32).
  final DataOwnerRepository _owner;
  final LogoutCleanerRegistry _cleaners;
  final OutboxRegistry _outboxes;
  final AppLogger _logger;
  final AppAnalytics _analytics;
  final _signedIn = StreamController<bool>.broadcast();

  /// A expiração percebida no boot: dados de alguém no aparelho e nenhuma
  /// sessão guardada (capítulo 32).
  final _expiredBeforeStart = StreamController<void>.broadcast();

  /// O estado da sessão, do ponto de vista do caso de uso: `true` quando
  /// alguém entrou (login, cadastro ou sessão restaurada), `false` quando a
  /// sessão terminou, sempre depois da limpeza dos dados (capítulo 11).
  /// Quem observa é o `SessionBloc`, e nunca o token.
  Stream<bool> watchSignedIn() => _signedIn.stream;

  /// `async` para que uma falha de validação chegue como erro do `Future`,
  /// e não como exceção síncrona antes de ele existir.
  ///
  /// O dono é lido antes de ir ao backend: se ele não puder ser lido, o
  /// login é recusado antes de qualquer token ser guardado (capítulo 32).
  Future<User> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final validEmail = EmailAddress.parse(email);
    final validPassword = Password.parse(password);
    final previousOwner = await _owner.currentOwner();
    final user = await _repository.signInWithPassword(
      validEmail,
      validPassword,
    );
    await _takeOwnership(user, previousOwner);
    _sessionStarted(user, method: 'password');
    return user;
  }

  Future<User> registerAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final validEmail = EmailAddress.parse(email);
    final validPassword = Password.parse(password);
    final previousOwner = await _owner.currentOwner();
    final user = await _repository.registerAccount(
      name: name.trim(),
      email: validEmail,
      password: validPassword,
    );
    await _takeOwnership(user, previousOwner);
    _identify(user);
    _signedIn.add(true);
    unawaited(_analytics.logEvent('auth_account_registered'));
    return user;
  }

  /// Chamado no boot. Uma sessão restaurada identifica o usuário nos
  /// relatórios de falha, mas não é um evento de produto.
  ///
  /// Sem sessão guardada, mas com dados de alguém no aparelho, a sessão
  /// dessa pessoa expirou com alterações não enviadas antes de o app ser
  /// fechado: o boot volta ao mesmo ponto, pelo mesmo caminho da expiração
  /// (capítulo 32).
  Future<User?> restoreSession() async {
    final previousOwner = await _owner.currentOwner();
    final user = await _repository.restoreSession();
    if (user == null) {
      if (previousOwner == null) {
        _signedIn.add(false);
      } else {
        _expiredBeforeStart.add(null);
      }
      return null;
    }
    await _takeOwnership(user, previousOwner);
    _identify(user);
    _signedIn.add(true);
    return user;
  }

  /// Quantas alterações feitas sem rede ainda não foram enviadas. A tela
  /// pede confirmação antes de sair quando há alguma.
  Future<int> pendingChanges() => _outboxes.pendingOperations();

  /// Encerra a sessão no backend e, aconteça o que acontecer, apaga os
  /// dados locais de todos os módulos e esquece o usuário nos relatórios.
  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } finally {
      await _forgetLocalSession();
    }
    unawaited(_analytics.logEvent('auth_session_ended'));
  }

  /// A expiração percebida pela renovação recusada e a percebida no boot.
  Stream<void> watchSessionExpired() => Stream.multi((controller) {
    final subscriptions = [
      _repository.watchSessionExpired().listen(controller.add),
      _expiredBeforeStart.stream.listen(controller.add),
    ];
    controller.onCancel = () => Future.wait([
      for (final subscription in subscriptions) subscription.cancel(),
    ]);
  });

  /// Encerra uma sessão que já expirou no servidor: só limpa os dados
  /// locais, porque não há o que encerrar no backend.
  Future<void> endExpiredSession() async {
    await _forgetLocalSession();
    unawaited(_analytics.logEvent('auth_session_expired'));
  }

  void _sessionStarted(User user, {required String method}) {
    _identify(user);
    _signedIn.add(true);
    unawaited(_analytics.logEvent('auth_session_started', {'method': method}));
  }

  void _identify(User user) => _logger.setUserId(user.id);

  /// Outra pessoa entrando depois de uma sessão expirada que ainda guardava
  /// alterações: os dados da anterior são apagados antes de a nova sessão
  /// começar (capítulo 11), e só depois o dono muda. Se a limpeza falhar,
  /// o dono anterior continua gravado, e a próxima entrada tenta de novo.
  /// A mesma pessoa encontra tudo como deixou, e a fila de envio segue.
  Future<void> _takeOwnership(User user, String? previousOwner) async {
    if (previousOwner == user.id) return;
    if (previousOwner != null) await _clearAll();
    await _owner.saveOwner(user.id);
  }

  /// Uma falha na limpeza vai para o registro de falhas e sobe para quem
  /// chamou: dados de outra pessoa podem ter ficado no aparelho.
  Future<void> _clearAll() async {
    try {
      await _cleaners.clearAll();
    } on Exception catch (error, stackTrace) {
      _logger.error('auth clear local data', error, stackTrace);
      rethrow;
    }
  }

  /// O dono só sai depois dos dados: uma limpeza que falhou deixa o dono
  /// gravado, e o próximo login de outra pessoa apaga de novo.
  Future<void> _forgetLocalSession() async {
    try {
      await _clearAll();
      await _owner.clearOwner();
    } finally {
      _logger.setUserId(null);
      // Depois da limpeza, mesmo que ela falhe: os tokens já foram apagados,
      // e a sessão acabou de qualquer jeito.
      _signedIn.add(false);
    }
  }
}
