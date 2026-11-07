import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/use_cases/auth_use_case.dart';
import '../../../domain/auth_failure.dart';

part 'login_event.dart';
part 'login_state.dart';

/// O ViewModel da tela de login. Depende só do caso de uso, a porta
/// driving do módulo.
///
/// Não é `final`: os testes da View o simulam com `implements`, como o
/// `AuthUseCase` (capítulo 20).
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required AuthUseCase auth})
    : _auth = auth,
      super(const LoginInitial()) {
    // Um envio por vez: toques repetidos durante o envio são ignorados.
    on<LoginSubmitted>(_onSubmitted, transformer: droppable());
  }

  final AuthUseCase _auth;

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginSubmitInProgress());
    try {
      await _auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );
      emit(const LoginSubmitSuccess());
    } on AuthFailure catch (failure) {
      emit(LoginSubmitFailure(failure));
    } on ApiError {
      emit(const LoginSubmitFailure.unavailable());
    } on LocalDatabaseError {
      // A sessão é gravada no banco do módulo (capítulo 21).
      emit(const LoginSubmitFailure.unavailable());
    }
  }
}
