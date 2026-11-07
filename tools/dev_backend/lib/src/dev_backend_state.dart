import 'dart:convert';
import 'dart:math';

/// Uma conta. A senha fica em texto puro porque nada aqui sai da memória
/// de um processo de desenvolvimento; um backend de verdade guarda só o
/// hash.
final class DevUser {
  DevUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String password;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Os dois tokens de uma sessão. O de acesso vence; o de renovação troca a
/// cada uso.
final class DevSession {
  DevSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String userId;
  String accessToken;
  String refreshToken;
  DateTime expiresAt;
}

/// Uma tarefa, com a versão que sobe a cada alteração aceita e os ids das
/// operações que a produziram (capítulo 12): um reenvio de uma operação já
/// aplicada recebe a tarefa como está, e não um conflito.
final class DevTask {
  DevTask({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  String title;
  String status;
  final DateTime createdAt;
  int version = 1;
  final Set<String> appliedOperations = {};

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'version': version,
  };
}

/// A próxima escrita de tarefa que o backend vai recusar, pedida pela rota
/// de desenvolvimento: o jeito de ver uma recusa que não é conflito.
final class DevRejection {
  const DevRejection({this.status = 422, this.code = 'rejected_by_dev'});

  final int status;
  final String code;
}

/// Uma resposta guardada sob um Idempotency-Key.
final class DevStoredResponse {
  const DevStoredResponse(this.requestBody, this.status, this.body);

  final String requestBody;
  final int status;
  final Object? body;
}

/// Todo o estado do backend, em memória.
final class DevBackendState {
  DevBackendState({
    DateTime Function()? now,
    this.tokenTtl = const Duration(minutes: 15),
    Random? random,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _random = random ?? Random.secure();

  final DateTime Function() _now;
  final Random _random;

  /// Quanto vale um token de acesso.
  final Duration tokenTtl;

  final users = <String, DevUser>{}; // pelo e-mail, em minúsculas
  final sessions = <DevSession>[];
  final tasks = <String, DevTask>{}; // pelo id que o app gerou
  final idempotency = <String, DevStoredResponse>{}; // usuário + chave
  DevRejection? rejectNext;

  /// A próxima escrita aceita responde sem a versão: um defeito do
  /// servidor, para ver o erro não fatal chegar ao Crashlytics (capítulo 38).
  var omitVersionNext = false;
  var _nextUser = 0;

  DateTime now() => _now();

  String newUserId() => 'u-${++_nextUser}';

  /// Um token opaco, aleatório.
  String newToken() =>
      base64Url.encode(List.generate(24, (_) => _random.nextInt(256)));

  DevSession openSession(DevUser user) {
    final session = DevSession(
      userId: user.id,
      accessToken: newToken(),
      refreshToken: newToken(),
      expiresAt: now().add(tokenTtl),
    );
    sessions.add(session);
    return session;
  }

  /// A sessão de um token de acesso ainda válido.
  DevSession? sessionOf(String accessToken) {
    for (final session in sessions) {
      if (session.accessToken == accessToken) {
        return now().isBefore(session.expiresAt) ? session : null;
      }
    }
    return null;
  }

  DevUser? userById(String id) {
    for (final user in users.values) {
      if (user.id == id) return user;
    }
    return null;
  }

  /// Rota de desenvolvimento: todos os tokens de acesso vencem agora.
  void expireTokens() {
    final past = now().subtract(const Duration(seconds: 1));
    for (final session in sessions) {
      session.expiresAt = past;
    }
  }

  void reset() {
    users.clear();
    sessions.clear();
    tasks.clear();
    idempotency.clear();
    rejectNext = null;
    omitVersionNext = false;
    _nextUser = 0;
  }
}
