import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/register_bloc.dart';
import '../views/register_view.dart';

final class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RegisterBloc>(
      create: (_) => GetIt.instance<RegisterBloc>(),
      child: const RegisterView(),
    );
  }
}
