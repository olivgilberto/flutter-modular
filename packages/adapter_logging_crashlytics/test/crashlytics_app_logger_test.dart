import 'package:adapter_logging_crashlytics/adapter_logging_crashlytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

final class _MockCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  late _MockCrashlytics crashlytics;
  late CrashlyticsAppLogger logger;
  final error = StateError('falhou');
  final stackTrace = StackTrace.current;

  setUp(() {
    crashlytics = _MockCrashlytics();
    logger = CrashlyticsAppLogger(crashlytics: crashlytics);
  });

  test('log vira um breadcrumb', () {
    when(() => crashlytics.log('abriu a lista')).thenAnswer((_) async {});

    logger.log('abriu a lista');

    verify(() => crashlytics.log('abriu a lista')).called(1);
  });

  test('error vira um erro não fatal, com o motivo', () {
    when(
      () => crashlytics.recordError(error, stackTrace, reason: 'outbox tasks'),
    ).thenAnswer((_) async {});

    logger.error('outbox tasks', error, stackTrace);

    verify(
      () => crashlytics.recordError(error, stackTrace, reason: 'outbox tasks'),
    ).called(1);
  });

  test('fatal vira um erro fatal', () {
    when(
      () => crashlytics.recordError(error, stackTrace, fatal: true),
    ).thenAnswer((_) async {});

    logger.fatal(error, stackTrace);

    verify(
      () => crashlytics.recordError(error, stackTrace, fatal: true),
    ).called(1);
  });

  test('setUserId(null) limpa o identificador', () {
    when(() => crashlytics.setUserIdentifier('')).thenAnswer((_) async {});

    logger.setUserId(null);

    verify(() => crashlytics.setUserIdentifier('')).called(1);
  });
}
