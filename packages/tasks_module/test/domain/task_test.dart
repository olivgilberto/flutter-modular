import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_module/domain/entities/task.dart';
import 'package:tasks_module/domain/value_objects/task_title.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 27, 9);
  final task = Task(
    id: 't-1',
    title: TaskTitle.parse('Comprar pão'),
    createdAt: createdAt,
  );

  test('nasce aberta', () {
    expect(task.status, TaskStatus.open);
    expect(task.isDone, isFalse);
    expect(task.isArchived, isFalse);
  });

  test('concluir, reabrir e renomear mantêm o id e a data de criação', () {
    final done = task.complete();
    expect(done.isDone, isTrue);
    expect(done.reopen().status, TaskStatus.open);

    final renamed = task.rename(TaskTitle.parse('Comprar pão e leite'));
    expect(renamed.title.value, 'Comprar pão e leite');
    for (final changed in [done, renamed]) {
      expect(changed.id, task.id);
      expect(changed.createdAt, createdAt);
    }
  });

  test('igualdade pelo id', () {
    expect(task.rename(TaskTitle.parse('Outro título')), task);
    expect(
      Task(id: 't-2', title: task.title, createdAt: createdAt),
      isNot(task),
    );
  });
}
