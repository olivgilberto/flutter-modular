import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tasks_module/adapters/driving/l10n/tasks_module_localizations.dart';
import 'package:tasks_module/domain/entities/task.dart';

/// As traduções do módulo (capítulo 37). Uma chave que falta numa tradução
/// não é erro para o gen-l10n: a tela mostra o texto do template, em
/// inglês, para quem escolheu português. Este teste transforma o aviso em
/// falha.
void main() {
  const arbDir = 'lib/adapters/driving/l10n';
  const template = 'tasks_module_en.arb';

  Map<String, Object?> read(String name) =>
      jsonDecode(File('$arbDir/$name').readAsStringSync())
          as Map<String, Object?>;

  Set<String> messages(Map<String, Object?> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  final translations = [
    for (final file in Directory(arbDir).listSync().whereType<File>())
      if (file.path.endsWith('.arb')) file.uri.pathSegments.last,
  ]..sort();

  test('há o template e pelo menos uma tradução', () {
    expect(translations, containsAll([template, 'tasks_module_pt.arb']));
  });

  test('toda tradução tem exatamente as chaves do template', () {
    final expected = messages(read(template));
    for (final name in translations) {
      final arb = read(name);
      expect(messages(arb), expected, reason: name);
      expect(
        name,
        'tasks_module_${arb['@@locale']}.arb',
        reason: 'o @@locale de $name',
      );
    }
  });

  test('o select da situação dá a palavra de cada idioma', () {
    final en = lookupTasksModuleLocalizations(const Locale('en'));
    final pt = lookupTasksModuleLocalizations(const Locale('pt', 'BR'));
    expect(en.taskSummary('Pay the bill', 'done'), '"Pay the bill", done');
    expect(pt.taskSummary('Pagar a luz', 'done'), '"Pagar a luz", concluída');
    // Em português nenhuma palavra coincide com o nome do valor do enum: um
    // valor novo do TaskStatus sem palavra no ARB cairia no `other`, que
    // repete o nome, e este teste o apontaria.
    for (final status in TaskStatus.values) {
      expect(
        pt.taskSummary('Pagar a luz', status.name),
        isNot(endsWith(', ${status.name}')),
        reason: '$status',
      );
    }
  });

  test('plural do aviso de conflitos nos dois idiomas', () {
    final en = lookupTasksModuleLocalizations(const Locale('en'));
    final pt = lookupTasksModuleLocalizations(const Locale('pt', 'BR'));
    expect(en.conflictsNotice(1), '1 change needs your decision');
    expect(en.conflictsNotice(2), '2 changes need your decision');
    expect(pt.conflictsNotice(1), '1 alteração precisa da sua decisão');
    expect(pt.conflictsNotice(2), '2 alterações precisam da sua decisão');
  });

  test('a armadilha do =1: em português, a categoria "one" vale para 0 e '
      'para 1', () {
    // O gen-l10n escreve o caso =1 do ARB como o parâmetro `one` do
    // Intl.pluralLogic. Para o português do Brasil, as regras do CLDR põem
    // o 0 na categoria "one", e sem um caso =0 o zero recebe a frase do 1.
    expect(
      Intl.pluralLogic(0, locale: 'pt', one: 'frase do 1', other: 'outra'),
      'frase do 1',
    );
    expect(
      Intl.pluralLogic(0, locale: 'en', one: 'frase do 1', other: 'outra'),
      'outra',
    );
    // Por isso todo plural do módulo tem o caso =0.
    final pt = lookupTasksModuleLocalizations(const Locale('pt', 'BR'));
    expect(pt.conflictsNotice(0), 'Nenhuma alteração precisa da sua decisão');
  });
}
