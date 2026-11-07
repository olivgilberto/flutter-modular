import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/logout_bloc.dart';
import '../views/logout_view.dart';

/// O ponto de entrada do logout, exportado para a moldura das telas que o
/// host monta (capítulo 29). Não é uma rota: sair é uma ação, e não uma
/// tela. Como uma Page, só obtém o Bloc e o entrega à View.
final class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LogoutBloc>(
      create: (_) => GetIt.instance<LogoutBloc>(),
      child: const LogoutView(),
    );
  }
}
