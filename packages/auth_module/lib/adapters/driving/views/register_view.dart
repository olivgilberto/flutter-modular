import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/auth_failure.dart';
import '../../../domain/value_objects/password.dart';
import '../bloc/register_bloc.dart';
import '../l10n/auth_module_localizations.dart';

final class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

final class _RegisterViewState extends State<RegisterView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => context.read<RegisterBloc>().add(
    RegisterSubmitted(
      name: _name.text,
      email: _email.text,
      password: _password.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegisterBloc>().state;
    final busy =
        state is RegisterSubmitInProgress || state is RegisterSubmitSuccess;

    final l10n = AuthModuleLocalizations.of(context);

    return AppForm(
      title: l10n.registerTitle,
      children: [
        AppTextField(
          controller: _name,
          label: l10n.nameLabel,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
        ),
        AppTextField(
          controller: _email,
          label: l10n.emailLabel,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        // newPassword: o gerenciador de senhas oferece uma senha gerada.
        AppTextField.password(
          controller: _password,
          label: l10n.registerPasswordLabel(Password.minLength),
          showLabel: l10n.showPassword,
          hideLabel: l10n.hidePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _submit(),
        ),
        if (state case RegisterSubmitFailure(:final failure))
          AppInlineError(
            message: failure == null
                ? l10n.registerUnexpectedError
                : _messageFor(l10n, failure),
          ),
        AppPrimaryButton(
          label: l10n.registerSubmit,
          loading: busy,
          onPressed: _submit,
        ),
      ],
    );
  }

  /// A mesma família de falhas, outras mensagens: no cadastro, a senha
  /// fraca precisa dizer o que mudar.
  static String _messageFor(
    AuthModuleLocalizations l10n,
    AuthFailure failure,
  ) => switch (failure) {
    InvalidEmailFailure() => l10n.checkEmail,
    WeakPasswordFailure() => l10n.registerWeakPassword(Password.minLength),
    EmailAlreadyRegisteredFailure() => l10n.registerEmailTaken,
    InvalidCredentialsFailure() => l10n.registerCheckData,
  };
}
