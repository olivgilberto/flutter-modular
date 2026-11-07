import 'package:adapter_analytics_firebase/adapter_analytics_firebase.dart';
import 'package:core/core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

final class _MockAnalytics extends Mock implements FirebaseAnalytics {}

final class _FakeLogger implements AppLogger {
  final errors = <String>[];

  @override
  void log(String message) {}

  @override
  void error(String reason, Object error, StackTrace stackTrace) =>
      errors.add(reason);

  @override
  void fatal(Object error, StackTrace stackTrace) {}

  @override
  void setUserId(String? opaqueId) {}
}

void main() {
  late _MockAnalytics analytics;
  late _FakeLogger logger;
  late FirebaseAppAnalytics adapter;

  setUp(() {
    analytics = _MockAnalytics();
    logger = _FakeLogger();
    adapter = FirebaseAppAnalytics(logger: logger, analytics: analytics);
  });

  test('um evento válido segue para o Firebase', () async {
    when(
      () => analytics.logEvent(
        name: 'tasks_task_archived',
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((_) async {});

    await adapter.logEvent('tasks_task_archived', {'source': 'list'});

    final parameters = verify(
      () => analytics.logEvent(
        name: 'tasks_task_archived',
        parameters: captureAny(named: 'parameters'),
      ),
    ).captured.single;
    expect(parameters, {'source': 'list'});
  });

  test('uma falha do plugin é registrada e nunca relançada', () async {
    when(
      () => analytics.logScreenView(screenName: 'tasks_list'),
    ).thenThrow(FirebaseException(plugin: 'firebase_analytics'));

    await adapter.logScreenView('tasks_list');

    expect(logger.errors, ['analytics screen view']);
  });

  test('a convenção de nomes', () {
    expect(FirebaseAppAnalytics.isValidEventName('tasks_task_archived'), true);
    expect(FirebaseAppAnalytics.isValidEventName('TasksTaskArchived'), false);
    expect(FirebaseAppAnalytics.isValidEventName('tasks_archived'), false);
    expect(FirebaseAppAnalytics.isValidEventName('firebase_x_y'), false);
    expect(
      FirebaseAppAnalytics.isValidEventName('tasks_${'a' * 30}_archived'),
      false,
    );
  });
}
