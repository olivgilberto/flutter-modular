import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_module/domain/task_failure.dart';
import 'package:tasks_module/domain/value_objects/task_title.dart';

void main() {
  test('tira os espaços das pontas', () {
    expect(TaskTitle.parse('  Comprar pão \n').value, 'Comprar pão');
  });

  test('vazio, ou só com espaços, não é título', () {
    expect(() => TaskTitle.parse(''), throwsA(isA<EmptyTaskTitleFailure>()));
    expect(
      () => TaskTitle.parse(' \t '),
      throwsA(isA<EmptyTaskTitleFailure>()),
    );
  });

  test('o limite conta pontos de código, depois de tirados os espaços', () {
    final atLimit = 'a' * TaskTitle.maxLength;
    expect(TaskTitle.parse('  $atLimit  ').value, atLimit);
    expect(
      () => TaskTitle.parse('${atLimit}a'),
      throwsA(isA<TaskTitleTooLongFailure>()),
    );
    // Um emoji fora do plano básico vale um ponto de código e duas
    // unidades UTF-16: 200 deles cabem.
    expect(TaskTitle.parse('🙂' * TaskTitle.maxLength).value.length, 400);
  });

  test('dois títulos com o mesmo texto são iguais', () {
    expect(TaskTitle.parse('Pagar a luz'), TaskTitle.parse(' Pagar a luz'));
  });
}
