import 'dart:io';

import 'dependency_rules.dart';
import 'workspace.dart';

/// O que o repositório guarda sobre os módulos fora do código (capítulo 42):
/// a página de cada um, o índice da arquitetura e o dono.
final class ModuleRecords {
  const ModuleRecords({
    required this.moduleDocs,
    required this.architecture,
    required this.codeOwners,
  });

  /// Os arquivos de docs/modules/, sem o .md.
  final Set<String> moduleDocs;

  /// O texto do docs/architecture.md.
  final String architecture;

  /// As linhas do .github/CODEOWNERS, na ordem do arquivo.
  final List<OwnerRule> codeOwners;

  static ModuleRecords read(Directory root) {
    final docs = Directory('${root.path}/docs/modules');
    final owners = File('${root.path}/.github/CODEOWNERS');
    return ModuleRecords(
      moduleDocs: {
        if (docs.existsSync())
          for (final f in docs.listSync().whereType<File>())
            if (f.path.endsWith('.md'))
              f.uri.pathSegments.last.replaceAll('.md', ''),
      },
      architecture: _readOrEmpty(File('${root.path}/docs/architecture.md')),
      codeOwners: parseCodeOwners(_readOrEmpty(owners)),
    );
  }

  static String _readOrEmpty(File f) =>
      f.existsSync() ? f.readAsStringSync() : '';
}

typedef OwnerRule = ({String pattern, List<String> owners});

/// Uma regra por linha: o padrão e os donos. Comentários e linhas vazias
/// ficam de fora.
List<OwnerRule> parseCodeOwners(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
      (
        pattern: line.trim().split(RegExp(r'\s+')).first,
        owners: line.trim().split(RegExp(r'\s+')).skip(1).toList(),
      ),
];

/// No GitHub, vale a última linha cujo padrão alcança o caminho. Aqui só os
/// padrões que o repositório usa: `*` e pastas a partir da raiz.
OwnerRule? effectiveRule(String path, List<OwnerRule> rules) {
  OwnerRule? found;
  for (final rule in rules) {
    final p = rule.pattern;
    if (p == '*' ||
        (p.startsWith('/') && p.endsWith('/') && '/$path/'.startsWith(p))) {
      found = rule;
    }
  }
  return found;
}

/// Cada módulo de feature tem página, entrada no índice e um dono só dele;
/// cada página de módulo corresponde a um módulo do workspace.
List<String> moduleRecordViolations(
  List<Package> packages,
  String project,
  ModuleRecords records,
) {
  final modules = [
    for (final p in packages)
      if (roleOf(p.name, p.path, project) == Role.module) p,
  ];
  final found = <String>[];
  for (final m in modules) {
    if (!records.moduleDocs.contains(m.name)) {
      found.add('${m.name}: falta docs/modules/${m.name}.md');
    }
    if (!records.architecture.contains('modules/${m.name}.md')) {
      found.add(
        '${m.name}: o docs/architecture.md não aponta para modules/${m.name}.md',
      );
    }
    final rule = effectiveRule(m.path, records.codeOwners);
    if (rule == null || rule.pattern != '/${m.path}/') {
      found.add(
        '${m.name}: sem linha própria no .github/CODEOWNERS '
        '(/${m.path}/ por último entre as que alcançam o módulo)',
      );
    } else if (rule.owners.isEmpty) {
      found.add('${m.name}: a linha /${m.path}/ do CODEOWNERS não tem dono');
    }
  }
  final names = {for (final m in modules) m.name};
  for (final doc in records.moduleDocs.difference(names)) {
    found.add('docs/modules/$doc.md: não há módulo $doc no workspace');
  }
  return found;
}
