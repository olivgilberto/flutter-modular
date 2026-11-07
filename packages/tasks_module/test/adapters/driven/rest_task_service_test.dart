import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tasks_module/adapters/driven/services/rest_task_service.dart';
import 'package:tasks_module/adapters/driven/task_api_paths.dart';

final class _MockApiClient extends Mock implements ApiClient {}

Map<String, Object?> _item(String id, {String title = 'Uma tarefa'}) => {
  'id': id,
  'title': title,
  'status': 'open',
  'createdAt': '2026-10-27T09:00:00.000Z',
  'version': 1,
};

void main() {
  late _MockApiClient api;
  late RestTaskService service;

  setUpAll(() => registerFallbackValue(<String, String>{}));

  setUp(() {
    api = _MockApiClient();
    service = RestTaskService(apiClient: api, pageSize: 2);
  });

  /// O backend responde à página pedida pelo cursor (`null` na primeira).
  void pages(Map<String?, Object?> byCursor) {
    when(
      () => api.get(TaskApiPaths.tasks, query: any(named: 'query')),
    ).thenAnswer((invocation) async {
      final query = invocation.namedArguments[#query] as Map<String, String>;
      return byCursor[query['cursor']];
    });
  }

  List<Map<String, String>> queries() => [
    for (final call in verify(
      () => api.get(TaskApiPaths.tasks, query: captureAny(named: 'query')),
    ).captured)
      call as Map<String, String>,
  ];

  test(
    'segue o cursor até a última página e devolve a lista inteira',
    () async {
      pages({
        null: {
          'items': [_item('t-1'), _item('t-2')],
          'nextCursor': 'c-2',
        },
        'c-2': {
          'items': [_item('t-3')],
          'nextCursor': null,
        },
      });

      final tasks = await service.fetchActiveTasks();

      expect([for (final task in tasks) task.id], ['t-1', 't-2', 't-3']);
      expect(queries(), [
        {'status': 'active', 'limit': '2'},
        {'status': 'active', 'limit': '2', 'cursor': 'c-2'},
      ]);
    },
  );

  test('uma página que falha derruba a busca inteira', () async {
    when(
      () => api.get(TaskApiPaths.tasks, query: any(named: 'query')),
    ).thenAnswer((invocation) async {
      final query = invocation.namedArguments[#query] as Map<String, String>;
      if (query['cursor'] == 'c-2') {
        throw const ApiError(ApiErrorKind.unreachable);
      }
      return {
        'items': [_item('t-1')],
        'nextCursor': 'c-2',
      };
    });

    await expectLater(
      service.fetchActiveTasks(),
      throwsA(
        isA<ApiError>().having((e) => e.kind, 'kind', ApiErrorKind.unreachable),
      ),
    );
  });

  test('uma resposta fora do formato, ou uma tarefa que o domínio recusa, é '
      'ApiError de resposta inválida', () async {
    final invalid = isA<ApiError>().having(
      (e) => e.kind,
      'kind',
      ApiErrorKind.invalidResponse,
    );

    pages({
      null: {'items': 'nada'},
    });
    await expectLater(service.fetchActiveTasks(), throwsA(invalid));

    pages({
      null: {
        'items': [_item('t-1', title: '  ')],
        'nextCursor': null,
      },
    });
    await expectLater(service.fetchActiveTasks(), throwsA(invalid));
  });

  test(
    'um cursor repetido para a busca, em vez de girar para sempre',
    () async {
      pages({
        null: {
          'items': [_item('t-1')],
          'nextCursor': 'c-2',
        },
        'c-2': {
          'items': [_item('t-2')],
          'nextCursor': 'c-2',
        },
      });

      await expectLater(
        service.fetchActiveTasks(),
        throwsA(
          isA<ApiError>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.invalidResponse,
          ),
        ),
      );
    },
  );

  group('uma tarefa só (capítulo 34)', () {
    final path = TaskApiPaths.task('t-1');

    test('busca a versão do servidor pelo id', () async {
      when(() => api.get(path)).thenAnswer(
        (_) async => {..._item('t-1', title: 'Pagar a luz'), 'version': 7},
      );

      final task = await service.fetchTask('t-1');

      expect(task?.title, 'Pagar a luz');
      expect(task?.version, 7);
    });

    test('404 é a tarefa apagada no servidor, e não uma falha', () async {
      when(
        () => api.get(path),
      ).thenThrow(const ApiError(ApiErrorKind.rejected, statusCode: 404));

      expect(await service.fetchTask('t-1'), isNull);
    });

    test('as outras falhas continuam falhas', () async {
      when(
        () => api.get(path),
      ).thenThrow(const ApiError(ApiErrorKind.unreachable));

      await expectLater(
        service.fetchTask('t-1'),
        throwsA(
          isA<ApiError>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.unreachable,
          ),
        ),
      );
    });

    test('uma resposta fora do formato, ou que o domínio recusa, é '
        'invalidResponse', () async {
      for (final body in [
        null,
        {'id': 't-1'},
        {..._item('t-1'), 'title': '   '},
      ]) {
        when(() => api.get(path)).thenAnswer((_) async => body);

        await expectLater(
          service.fetchTask('t-1'),
          throwsA(
            isA<ApiError>().having(
              (e) => e.kind,
              'kind',
              ApiErrorKind.invalidResponse,
            ),
          ),
        );
      }
    });
  });
}
