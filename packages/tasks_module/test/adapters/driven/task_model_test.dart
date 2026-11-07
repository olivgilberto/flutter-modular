import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_module/adapters/driven/models/task_model.dart';
import 'package:tasks_module/domain/entities/task.dart';
import 'package:tasks_module/domain/task_failure.dart';
import 'package:tasks_module/domain/value_objects/task_title.dart';

void main() {
  final row = <String, Object?>{
    'id': 't-1',
    'title': 'Comprar pão',
    'status': 'done',
    'created_at': DateTime.utc(2026, 10, 27, 9).millisecondsSinceEpoch,
    'version': 4,
  };

  test('a linha vira a tarefa, e a tarefa volta à mesma linha, com a versão '
      'zerada de quem ainda não falou com o backend', () {
    final model = TaskModel.fromMap(row);
    final task = model.toEntity();

    expect(model.version, 4);
    expect(task.id, 't-1');
    expect(task.title, TaskTitle.parse('Comprar pão'));
    expect(task.status, TaskStatus.done);
    expect(task.createdAt, DateTime.utc(2026, 10, 27, 9));
    expect(task.createdAt.isUtc, isTrue);
    expect(TaskModel.fromEntity(task).toMap(), {...row, 'version': 0});
  });

  test('coluna a menos, ou de outro tipo, é FormatException', () {
    expect(
      () => TaskModel.fromMap({...row}..remove('status')),
      throwsFormatException,
    );
    expect(
      () => TaskModel.fromMap({...row, 'created_at': '2026-10-27'}),
      throwsFormatException,
    );
  });

  test('uma situação desconhecida ou um título que o domínio recusa não '
      'viram tarefa', () {
    expect(
      () => TaskModel.fromMap({...row, 'status': 'deleted'}).toEntity(),
      throwsFormatException,
    );
    expect(
      () => TaskModel.fromMap({...row, 'title': '  '}).toEntity(),
      throwsA(isA<EmptyTaskTitleFailure>()),
    );
  });

  group('a tarefa do backend', () {
    final json = <String, Object?>{
      'id': 't-1',
      'title': 'Comprar pão',
      'status': 'open',
      'createdAt': '2026-10-27T09:00:00.000Z',
      'version': 3,
      'ownerId': 'u-1',
    };

    test('vira o mesmo modelo que o banco guarda, ignorando o que sobra', () {
      final model = TaskModel.fromJson(json);

      expect(model.toMap(), {
        'id': 't-1',
        'title': 'Comprar pão',
        'status': 'open',
        'created_at': DateTime.utc(2026, 10, 27, 9).millisecondsSinceEpoch,
        'version': 3,
      });
    });

    test('uma data sem fuso, ou fora do formato, é FormatException', () {
      expect(
        () => TaskModel.fromJson({...json, 'createdAt': '2026-10-27T09:00:00'}),
        throwsFormatException,
      );
      expect(
        () => TaskModel.fromJson({...json, 'createdAt': 'ontem'}),
        throwsFormatException,
      );
      expect(
        () => TaskModel.fromJson({...json}..remove('version')),
        throwsFormatException,
      );
    });
  });
}
