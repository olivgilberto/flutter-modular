/// Rascunho do capítulo 42: um módulo novo pelo checklist do capítulo 28.
library;

import 'package:get_it/get_it.dart';

export 'adapters/driving/l10n/notes_module_localizations.dart'
    show NotesModuleLocalizations;
export 'adapters/driving/routes/notes_module_routes.dart'
    show NoteRoutes, notesModuleRoutes;

/// Registra o módulo no escopo da sessão. O rascunho ainda não tem domínio
/// nem dados; a função existe para o host já ter onde chamá-lo.
void registerNotesModuleDependencies(GetIt getIt) {}
