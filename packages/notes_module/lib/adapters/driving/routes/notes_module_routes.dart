import 'package:go_router/go_router.dart';

import '../pages/notes_page.dart';

abstract final class NoteRoutes {
  static const list = 'notes.list';
  static const listPath = '/notes';
}

final List<RouteBase> notesModuleRoutes = List.unmodifiable([
  GoRoute(
    name: NoteRoutes.list,
    path: NoteRoutes.listPath,
    builder: (context, state) => const NotesPage(),
  ),
]);
