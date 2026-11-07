import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../application/use_cases/auth_use_case.dart';
import '../../../domain/auth_failure.dart';

part 'register_event.dart';
part 'register_state.dart';

/// O ViewModel da tela de cadastro, com a mesma forma do `LoginBloc`.
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc({required AuthUseCase auth})
    : _auth = auth,
      super(const RegisterInitial()) {
    on<RegisterSubmitted>(_onSubmitted, transformer: droppable());
  }

  final AuthUseCase _auth;

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    emit(const RegisterSubmitInProgress());
    try {
      await _auth.registerAccount(
        name: event.name,
        email: event.email,
        password: event.password,
      );
      emit(const RegisterSubmitSuccess());
    } on AuthFailure catch (failure) {
      emit(RegisterSubmitFailure(failure));
    } on ApiError {
      emit(const RegisterSubmitFailure.unavailable());
    } on LocalDatabaseError {
      emit(const RegisterSubmitFailure.unavailable());
    }
  }
}
