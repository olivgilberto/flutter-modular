import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:notes_module/notes_module.dart';

void main() {
  test('o registro não pede nada ao escopo', () {
    registerNotesModuleDependencies(GetIt.asNewInstance());
  });

  testWidgets('a rota do módulo abre a tela, em português', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('pt'),
        supportedLocales: const [Locale('en'), Locale('pt')],
        localizationsDelegates: const [
          NotesModuleLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: GoRouter(
          initialLocation: NoteRoutes.listPath,
          routes: notesModuleRoutes,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma nota ainda'), findsOneWidget);
  });
}
