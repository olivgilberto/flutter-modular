import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/login_bloc.dart';
import '../session/session_bloc.dart';
import '../views/login_view.dart';

/// O ponto de entrada da rota `auth.login`: obtém um Bloc novo e o entrega
/// à View, com o aviso da sessão expirada quando há um (capítulo 29). As
/// Pages e o `LogoutButton` são os únicos pontos do lado driving que
/// consultam o `get_it`.
final class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = GetIt.instance<SessionBloc>();
    return BlocProvider<LoginBloc>(
      create: (_) => GetIt.instance<LoginBloc>(),
      // O SessionBloc é do escopo base e vive além da tela: só é lido aqui,
      // nunca fechado por ela.
      child: BlocBuilder<SessionBloc, SessionState>(
        bloc: session,
        builder: (context, state) => LoginView(
          expiredSession: state is SessionExpiredWithPendingChanges
              ? state
              : null,
          onDiscard: () => session.add(const SessionDiscardRequested()),
        ),
      ),
    );
  }
}
