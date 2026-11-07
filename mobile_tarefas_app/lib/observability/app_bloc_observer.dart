import 'package:bloc/bloc.dart';
import 'package:core/core.dart';

/// O quarto caminho até o registro de falhas (capítulo 14). Um erro que
/// escapa do handler de um evento chega ao `onError` do Bloc e daqui ao
/// [AppLogger], como erro não fatal: ele não derruba o app, mas é um bug.
/// O host o instala; nenhum módulo conhece o observer.
final class AppBlocObserver extends BlocObserver {
  const AppBlocObserver(this._logger);

  final AppLogger _logger;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _logger.error('bloc ${bloc.runtimeType}', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
