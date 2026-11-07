import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/logout_bloc.dart';
import '../l10n/auth_module_localizations.dart';

/// O botão "Sair" e a confirmação. Com alterações não enviadas, quem
/// decide é o usuário; sem nenhuma, o logout segue direto.
final class LogoutView extends StatelessWidget {
  const LogoutView({super.key});

  Future<void> _onStateChanged(BuildContext context, LogoutState state) async {
    final l10n = AuthModuleLocalizations.of(context);
    final String? warning;
    switch (state) {
      case LogoutCheckSuccess(pendingChanges: 0):
        warning = null;
      case LogoutCheckSuccess(:final pendingChanges):
        warning = l10n.logoutLostChanges(pendingChanges);
      case LogoutCheckFailure():
        warning = l10n.logoutCheckFailed;
      default:
        return;
    }
    final bloc = context.read<LogoutBloc>();
    if (warning != null &&
        !await showAppConfirmDialog(
          context,
          title: l10n.logoutTitle,
          message: warning,
          confirmLabel: l10n.logoutConfirm,
          cancelLabel: l10n.cancel,
        )) {
      return;
    }
    bloc.add(const LogoutConfirmed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LogoutBloc, LogoutState>(
      listener: _onStateChanged,
      builder: (context, state) {
        // Depois do sucesso o botão continua desabilitado até o redirect.
        final busy =
            state is LogoutCheckInProgress ||
            state is LogoutSubmitInProgress ||
            state is LogoutSubmitSuccess;
        return AppTextButton(
          label: AuthModuleLocalizations.of(context).logout,
          onPressed: busy
              ? null
              : () => context.read<LogoutBloc>().add(const LogoutRequested()),
        );
      },
    );
  }
}
