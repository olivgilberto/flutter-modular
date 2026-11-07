import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/get_it_outside_edges.dart';
import 'src/rules/layer_imports.dart';

/// O plugin do analisador do workspace (capítulos 15 e 40). O analisador
/// gera um código que importa este arquivo e usa a variável [plugin].
final plugin = WorkspaceLintsPlugin();

final class WorkspaceLintsPlugin extends Plugin {
  @override
  String get name => 'workspace_lints';

  /// Regras de lint vêm desligadas: o analysis_options.yaml da raiz liga
  /// cada uma, em plugins > workspace_lints > diagnostics.
  @override
  void register(PluginRegistry registry) {
    registry
      ..registerLintRule(GetItOutsideEdges())
      ..registerLintRule(LayerImports());
  }
}
