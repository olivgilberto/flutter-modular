import 'package:auth_module/application/ports/auth_repository.dart';
import 'package:auth_module/application/use_cases/auth_use_case.dart';
import 'package:auth_module/domain/auth_failure.dart';
import 'package:auth_module/domain/entities/user.dart';
import 'package:auth_module/domain/value_objects/email_address.dart';
import 'package:auth_module/domain/value_objects/password.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes.dart';

final class MockAuthRepository extends Mock implements AuthRepository {}

final class MockLogoutCleanerRegistry extends Mock
    implements LogoutCleanerRegistry {}

final class MockOutboxRegistry extends Mock implements OutboxRegistry {}

void main() {
  late MockAuthRepository repository;
  late MockLogoutCleanerRegistry cleaners;
  late MockOutboxRegistry outboxes;
  late FakeDataOwnerRepository owner;
  late FakeLogger logger;
  late FakeAnalytics analytics;
  late AuthUseCase useCase;

  final ana = User(
    id: 'u-1',
    name: 'Ana',
    email: EmailAddress.parse('ana@exemplo.com'),
  );
  const strongPassword = 'cavalo-bateria-grampo';

  setUpAll(() {
    registerFallbackValue(EmailAddress.parse('fallback@exemplo.com'));
    registerFallbackValue(Password.parse('fallback-senha-longa'));
  });

  setUp(() {
    repository = MockAuthRepository();
    cleaners = MockLogoutCleanerRegistry();
    outboxes = MockOutboxRegistry();
    owner = FakeDataOwnerRepository();
    logger = FakeLogger();
    analytics = FakeAnalytics();
    when(
      () => repository.watchSessionExpired(),
    ).thenAnswer((_) => const Stream.empty());
    useCase = AuthUseCase(
      repository: repository,
      owner: owner,
      cleaners: cleaners,
      outboxes: outboxes,
      logger: logger,
      analytics: analytics,
    );
    when(() => cleaners.clearAll()).thenAnswer((_) async {});
  });

  group('login', () {
    test('e-mail inválido não chega ao repositório', () async {
      await expectLater(
        useCase.signInWithPassword(
          email: 'sem-arroba',
          password: strongPassword,
        ),
        throwsA(isA<InvalidEmailFailure>()),
      );
      verifyNever(() => repository.signInWithPassword(any(), any()));
    });

    test('senha curta não chega ao repositório', () async {
      await expectLater(
        useCase.signInWithPassword(email: 'ana@exemplo.com', password: 'curta'),
        throwsA(isA<WeakPasswordFailure>()),
      );
      verifyNever(() => repository.signInWithPassword(any(), any()));
    });

    test('o sucesso identifica o usuário e registra o evento', () async {
      when(
        () => repository.signInWithPassword(any(), any()),
      ).thenAnswer((_) async => ana);

      final user = await useCase.signInWithPassword(
        email: ' Ana@Exemplo.com ',
        password: strongPassword,
      );

      expect(user, ana);
      verify(
        () => repository.signInWithPassword(
          EmailAddress.parse('ana@exemplo.com'),
          Password.parse(strongPassword),
        ),
      ).called(1);
      expect(logger.userIds, ['u-1']);
      expect(analytics.events, ['auth_session_started']);
      expect(analytics.parameters['auth_session_started'], {
        'method': 'password',
      });
    });

    test('a recusa do backend não identifica ninguém', () async {
      when(
        () => repository.signInWithPassword(any(), any()),
      ).thenThrow(const InvalidCredentialsFailure());

      await expectLater(
        useCase.signInWithPassword(
          email: 'ana@exemplo.com',
          password: strongPassword,
        ),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
      expect(logger.userIds, isEmpty);
      expect(analytics.events, isEmpty);
    });
  });

  test('o cadastro remove espaços do nome e registra o evento', () async {
    when(
      () => repository.registerAccount(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => ana);

    await useCase.registerAccount(
      name: '  Ana ',
      email: 'ana@exemplo.com',
      password: strongPassword,
    );

    verify(
      () => repository.registerAccount(
        name: any(named: 'name', that: equals('Ana')),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).called(1);
    expect(analytics.events, ['auth_account_registered']);
  });

  test('a sessão restaurada identifica o usuário, sem evento', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => ana);

    expect(await useCase.restoreSession(), ana);
    expect(logger.userIds, ['u-1']);
    expect(analytics.events, isEmpty);
  });

  group('logout', () {
    test('encerra a sessão e depois limpa os dados', () async {
      when(() => repository.signOut()).thenAnswer((_) async {});

      await useCase.signOut();

      verifyInOrder([() => repository.signOut(), () => cleaners.clearAll()]);
      expect(logger.userIds, [null]);
      expect(analytics.events, ['auth_session_ended']);
    });

    test(
      'limpa os dados e esquece o usuário mesmo se o backend falhar',
      () async {
        final error = Exception('backend fora do ar');
        when(() => repository.signOut()).thenThrow(error);

        await expectLater(useCase.signOut(), throwsA(same(error)));

        verify(() => cleaners.clearAll()).called(1);
        expect(logger.userIds, [null]);
        expect(analytics.events, isEmpty);
      },
    );

    test('sessão expirada limpa os dados sem chamar o backend', () async {
      await useCase.endExpiredSession();

      verify(() => cleaners.clearAll()).called(1);
      verifyNever(() => repository.signOut());
      expect(logger.userIds, [null]);
      expect(analytics.events, ['auth_session_expired']);
    });

    test('as pendências vêm das filas de todos os módulos', () async {
      when(() => outboxes.pendingOperations()).thenAnswer((_) async => 3);

      expect(await useCase.pendingChanges(), 3);
    });
  });

  group('estado da sessão', () {
    late List<bool> published;

    setUp(() {
      published = [];
      useCase.watchSignedIn().listen(published.add);
    });

    test('login, cadastro e sessão restaurada publicam a sessão aberta; '
        'sem sessão guardada, publica o contrário', () async {
      when(
        () => repository.signInWithPassword(any(), any()),
      ).thenAnswer((_) async => ana);
      when(
        () => repository.registerAccount(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => ana);
      when(() => repository.restoreSession()).thenAnswer((_) async => null);

      await useCase.restoreSession();
      await useCase.signInWithPassword(
        email: 'ana@exemplo.com',
        password: strongPassword,
      );
      await useCase.registerAccount(
        name: 'Ana',
        email: 'ana@exemplo.com',
        password: strongPassword,
      );
      await pumpEventQueue();

      expect(published, [false, true, true]);
    });

    test('a recusa do backend não publica nada', () async {
      when(
        () => repository.signInWithPassword(any(), any()),
      ).thenThrow(const InvalidCredentialsFailure());

      await expectLater(
        useCase.signInWithPassword(
          email: 'ana@exemplo.com',
          password: strongPassword,
        ),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
      await pumpEventQueue();

      expect(published, isEmpty);
    });

    test('o fim da sessão só é publicado depois da limpeza', () async {
      when(() => repository.signOut()).thenAnswer((_) async {});
      List<bool>? duringCleanup;
      when(() => cleaners.clearAll()).thenAnswer((_) async {
        await pumpEventQueue();
        duringCleanup = [...published];
      });

      await useCase.signOut();
      await pumpEventQueue();

      expect(duringCleanup, isEmpty);
      expect(published, [false]);
    });

    test('a sessão expirada também termina publicada', () async {
      await useCase.endExpiredSession();
      await pumpEventQueue();

      expect(published, [false]);
    });
  });

  group('outra pessoa depois de uma sessão expirada', () {
    final bia = User(
      id: 'u-2',
      name: 'Bia',
      email: EmailAddress.parse('bia@exemplo.com'),
    );

    void signInAnswers(User user) => when(
      () => repository.signInWithPassword(any(), any()),
    ).thenAnswer((_) async => user);

    test('apaga os dados da anterior antes de a nova sessão começar', () async {
      final published = <bool>[];
      useCase.watchSignedIn().listen(published.add);
      signInAnswers(ana);
      await useCase.signInWithPassword(
        email: 'ana@exemplo.com',
        password: strongPassword,
      );
      // A sessão de Ana expira com alterações pendentes: ninguém chama
      // endExpiredSession, e os dados dela continuam no aparelho.
      await pumpEventQueue();
      List<bool>? duringCleanup;
      when(() => cleaners.clearAll()).thenAnswer((_) async {
        await pumpEventQueue();
        duringCleanup = [...published];
      });

      signInAnswers(bia);
      await useCase.signInWithPassword(
        email: 'bia@exemplo.com',
        password: strongPassword,
      );
      await pumpEventQueue();

      verify(() => cleaners.clearAll()).called(1);
      expect(duringCleanup, [true]);
      expect(published, [true, true]);
      expect(logger.userIds, ['u-1', 'u-2']);
    });

    test('a mesma pessoa encontra tudo como deixou', () async {
      signInAnswers(ana);
      await useCase.signInWithPassword(
        email: 'ana@exemplo.com',
        password: strongPassword,
      );
      await useCase.signInWithPassword(
        email: 'ana@exemplo.com',
        password: strongPassword,
      );

      verifyNever(() => cleaners.clearAll());
    });

    test('depois de um logout completo, não há o que apagar', () async {
      signInAnswers(ana);
      when(() => repository.signOut()).thenAnswer((_) async {});
      await useCase.signInWithPassword(
        email: 'ana@exemplo.com',
        password: strongPassword,
      );
      await useCase.signOut();
      clearInteractions(cleaners);

      signInAnswers(bia);
      await useCase.signInWithPassword(
        email: 'bia@exemplo.com',
        password: strongPassword,
      );

      verifyNever(() => cleaners.clearAll());
    });
  });

  test('uma falha na limpeza vai para o registro de falhas e sobe', () async {
    when(() => repository.signOut()).thenAnswer((_) async {});
    when(
      () => cleaners.clearAll(),
    ).thenThrow(const LocalDatabaseError('banco travado'));

    await expectLater(useCase.signOut(), throwsA(isA<LocalDatabaseError>()));

    expect(logger.errors, ['auth clear local data']);
    expect(logger.userIds, [null]);
  });

  group('o dono dos dados, gravado (capítulo 32)', () {
    final bia = User(
      id: 'u-2',
      name: 'Bia',
      email: EmailAddress.parse('bia@exemplo.com'),
    );

    void signInAnswers(User user) => when(
      () => repository.signInWithPassword(any(), any()),
    ).thenAnswer((_) async => user);

    Future<void> signIn(String email) =>
        useCase.signInWithPassword(email: email, password: strongPassword);

    test('o login grava o dono; o logout o apaga depois dos dados', () async {
      signInAnswers(ana);
      when(() => repository.signOut()).thenAnswer((_) async {});
      String? ownerDuringCleanup;
      when(() => cleaners.clearAll()).thenAnswer((_) async {
        ownerDuringCleanup = owner.owner;
      });

      await signIn('ana@exemplo.com');
      expect(owner.owner, 'u-1');

      await useCase.signOut();
      expect(ownerDuringCleanup, 'u-1');
      expect(owner.owner, isNull);
    });

    test('outra pessoa depois de um reinício: o dono gravado faz a limpeza '
        'acontecer antes, e só então muda', () async {
      // O app foi reaberto: a memória está vazia, o banco não.
      owner.owner = 'u-1';
      signInAnswers(bia);
      String? ownerDuringCleanup;
      when(() => cleaners.clearAll()).thenAnswer((_) async {
        ownerDuringCleanup = owner.owner;
      });

      await signIn('bia@exemplo.com');

      verify(() => cleaners.clearAll()).called(1);
      expect(ownerDuringCleanup, 'u-1');
      expect(owner.owner, 'u-2');
    });

    test('a limpeza que falha mantém o dono anterior, e a próxima entrada '
        'tenta de novo', () async {
      owner.owner = 'u-1';
      signInAnswers(bia);
      when(
        () => cleaners.clearAll(),
      ).thenThrow(const LocalDatabaseError('banco travado'));

      await expectLater(
        signIn('bia@exemplo.com'),
        throwsA(isA<LocalDatabaseError>()),
      );
      expect(owner.owner, 'u-1');

      when(() => cleaners.clearAll()).thenAnswer((_) async {});
      await signIn('bia@exemplo.com');
      expect(owner.owner, 'u-2');
    });

    test('um dono ilegível recusa o login antes de ir ao backend', () async {
      owner.failing = true;
      final published = <bool>[];
      useCase.watchSignedIn().listen(published.add);

      await expectLater(
        signIn('bia@exemplo.com'),
        throwsA(isA<LocalDatabaseError>()),
      );
      await pumpEventQueue();

      verifyNever(() => repository.signInWithPassword(any(), any()));
      expect(published, isEmpty);
    });

    test('no boot, sem sessão guardada mas com dono, a sessão expirou antes '
        'de o app fechar: nada é publicado, e a expiração é avisada', () async {
      owner.owner = 'u-1';
      when(() => repository.restoreSession()).thenAnswer((_) async => null);
      final published = <bool>[];
      var expirations = 0;
      useCase.watchSignedIn().listen(published.add);
      useCase.watchSessionExpired().listen((_) => expirations++);

      expect(await useCase.restoreSession(), isNull);
      await pumpEventQueue();

      expect(published, isEmpty);
      expect(expirations, 1);
      verifyNever(() => cleaners.clearAll());
    });

    test('no boot, a sessão guardada de outra pessoa também limpa os dados '
        'do dono anterior antes de ser publicada', () async {
      owner.owner = 'u-1';
      when(() => repository.restoreSession()).thenAnswer((_) async => bia);

      expect(await useCase.restoreSession(), bia);

      verify(() => cleaners.clearAll()).called(1);
      expect(owner.owner, 'u-2');
    });

    test('uma sessão guardada antes deste capítulo, sem dono, ganha o '
        'dono', () async {
      when(() => repository.restoreSession()).thenAnswer((_) async => ana);

      await useCase.restoreSession();

      verifyNever(() => cleaners.clearAll());
      expect(owner.owner, 'u-1');
    });
  });
}
