import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/use_cases/auth_use_case.dart';

part 'logout_event.dart';
part 'logout_state.dart';

/// O ViewModel do botão de sair. Duas operações, cada uma com o seu
/// evento: a verificação das alterações não enviadas e o logout em si
/// (capítulo 11). Entre as duas, quem decide é o usuário, na View.
///
/// Não é `final`: os testes da View o simulam, como os outros Blocs.
class LogoutBloc extends Bloc<LogoutEvent, LogoutState> {
  LogoutBloc({required AuthUseCase auth})
    : _auth = auth,
      super(const LogoutInitial()) {
    on<LogoutRequested>(_onRequested, transformer: droppable());
    on<LogoutConfirmed>(_onConfirmed, transformer: droppable());
  }

  final AuthUseCase _auth;

  Future<void> _onRequested(
    LogoutRequested event,
    Emitter<LogoutState> emit,
  ) async {
    emit(const LogoutCheckInProgress());
    try {
      emit(LogoutCheckSuccess(pendingChanges: await _auth.pendingChanges()));
    } on LocalDatabaseError {
      // Sem saber quantas, a View pergunta do mesmo jeito.
      emit(const LogoutCheckFailure());
    }
  }

  Future<void> _onConfirmed(
    LogoutConfirmed event,
    Emitter<LogoutState> emit,
  ) async {
    emit(const LogoutSubmitInProgress());
    try {
      await _auth.signOut();
      emit(const LogoutSubmitSuccess());
    } on ApiError {
      // O backend não ficou sabendo, mas os dados locais já foram apagados
      // e o token, esquecido: para o aparelho, a sessão acabou.
      emit(const LogoutSubmitSuccess());
    } on LocalDatabaseError {
      emit(const LogoutSubmitFailure());
    }
  }
}
