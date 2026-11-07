import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'import_location.dart';

/// O `get_it` só nas bordas (capítulos 10 e 15): o composition root do host
/// (`lib/bootstrap/`), o arquivo de entrada de cada módulo
/// (`lib/[pacote].dart`), as Pages (`lib/adapters/driving/pages/`) e os
/// testes. Em qualquer outro lugar, ele vira um localizador de serviços, e
/// a classe passa a esconder do que depende.
final class GetItOutsideEdges extends AnalysisRule {
  GetItOutsideEdges()
    : super(
        name: 'get_it_outside_edges',
        description:
            'O get_it só no composition root, no arquivo de entrada de cada '
            'módulo, nas Pages e nos testes.',
      );

  static const LintCode code = LintCode(
    'get_it_outside_edges',
    "O get_it não pode ser importado em '{0}'.",
    correctionMessage:
        'Receba a dependência pelo construtor; quem resolve no get_it é o '
        'composition root, o arquivo de entrada do módulo ou uma Page.',
  );

  @override
  LintCode get diagnosticCode => code;

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

  /// Se [file], relativo à raiz do pacote [packageName], pode usar o get_it.
  static bool isEdge(String packageName, String file) =>
      !file.startsWith('lib/') ||
      file == 'lib/$packageName.dart' ||
      file.startsWith('lib/bootstrap/') ||
      file.startsWith('lib/adapters/driving/pages/');
}

final class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final GetItOutsideEdges rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) => _check(node);

  @override
  void visitExportDirective(ExportDirective node) => _check(node);

  void _check(NamespaceDirective node) {
    if (ImportLocation.packageOf(node) != 'get_it') return;
    final location = ImportLocation.of(context);
    if (location == null) return;
    if (GetItOutsideEdges.isEdge(location.packageName, location.file)) return;
    rule.reportAtNode(node.uri, arguments: [location.file]);
  }
}
