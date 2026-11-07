import 'dart:io';

import 'package:workspace_lints/workspace_lints.dart';

/// Rodado pelo script check-deps, na raiz do workspace.
void main() {
  final workspace = Workspace.read(Directory.current);
  final found = [
    for (final p in workspace.packages)
      ...violations(p, workspace.project, workspace.toolNames),
    // Capítulo 42: a página, o índice e o dono de cada módulo.
    ...moduleRecordViolations(
      workspace.packages,
      workspace.project,
      ModuleRecords.read(Directory.current),
    ),
  ];
  if (found.isEmpty) {
    final modules = workspace.packages
        .where((p) => roleOf(p.name, p.path, workspace.project) == Role.module)
        .length;
    stdout.writeln(
      'Fronteiras entre pacotes: nenhuma violação em ${workspace.packages.length} pacote(s). '
      'Módulos com página, índice e dono: $modules.',
    );
    return;
  }
  found.forEach(stderr.writeln);
  exit(1);
}
