import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'import_location.dart';

/// As setas apontam para dentro (capítulos 2 e 15): cada camada de um
/// módulo só importa as de dentro. O arquivo de entrada do módulo fica de
/// fora, porque ele é o composition root do módulo e conhece todas.
final class LayerImports extends AnalysisRule {
  LayerImports()
    : super(
        name: 'layer_imports',
        description:
            'Cada camada de um módulo só importa as camadas de dentro.',
      );

  static const LintCode code = LintCode(
    'layer_imports',
    "A camada '{0}' não pode importar '{1}'.",
    correctionMessage:
        'As setas apontam para dentro: domínio no centro, a aplicação em '
        'volta dele, e os adaptadores, driving e driven, na borda, sem se '
        'importarem um ao outro.',
  );

  @override
  LintCode get diagnosticCode => code;

  /// Para cada camada, o que ela não pode importar: pastas do mesmo pacote
  /// (relativas à raiz dele) e pacotes; `flutter` vale também para os
  /// `flutter_*`.
  static const forbidden =
      <String, ({List<String> folders, List<String> packages})>{
        'lib/domain/': (
          folders: ['lib/application/', 'lib/adapters/'],
          packages: ['flutter'],
        ),
        'lib/application/': (folders: ['lib/adapters/'], packages: ['flutter']),
        'lib/adapters/driving/': (
          folders: ['lib/adapters/driven/', 'lib/application/ports/'],
          packages: [],
        ),
        'lib/adapters/driven/': (
          folders: ['lib/adapters/driving/'],
          packages: [],
        ),
      };

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry
      ..addImportDirective(this, visitor)
      ..addExportDirective(this, visitor);
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final LayerImports rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) => _check(node);

  @override
  void visitExportDirective(ExportDirective node) => _check(node);

  void _check(NamespaceDirective node) {
    final location = ImportLocation.of(context);
    if (location == null) return;
    for (final MapEntry(key: layer, value: rules)
        in LayerImports.forbidden.entries) {
      if (!location.file.startsWith(layer)) continue;
      final package = ImportLocation.packageOf(node);
      if (package != null &&
          package != location.packageName &&
          rules.packages.any(
            (name) => package == name || package.startsWith('${name}_'),
          )) {
        rule.reportAtNode(node.uri, arguments: [layer, 'package:$package']);
        return;
      }
      final target = location.targetInPackage(node);
      if (target == null) return;
      for (final folder in rules.folders) {
        if (target.startsWith(folder)) {
          rule.reportAtNode(node.uri, arguments: [layer, folder]);
          return;
        }
      }
    }
  }
}
