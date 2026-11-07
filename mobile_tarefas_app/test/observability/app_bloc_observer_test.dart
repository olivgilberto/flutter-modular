import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tarefas_app/observability/app_bloc_observer.dart';

import '../support/fakes.dart';

final class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);

  /// O que um handler faria com um erro que não sabe tratar.
  void fail() => addError(StateError('bug'));
}

void main() {
  test('o erro que escapa de um Bloc chega ao registro, como não '
      'fatal', () async {
    final previous = Bloc.observer;
    addTearDown(() => Bloc.observer = previous);
    final logger = FakeLogger();
    Bloc.observer = AppBlocObserver(logger);

    final cubit = _CounterCubit()..fail();
    await cubit.close();

    expect(logger.errors, ['bloc _CounterCubit']);
    expect(logger.fatals, isEmpty);
  });
}
