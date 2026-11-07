import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// Onde está o arquivo analisado e para onde aponta um import ou export,
/// os dois em caminhos relativos à raiz do pacote ("lib/domain/task.dart").
/// As duas regras do plugin decidem só por esses caminhos: o nome da pasta
/// do pacote é o nome do pacote no workspace (capítulo 16).
final class ImportLocation {
  ImportLocation._(this.packageName, this.file);

  /// `null` quando o arquivo não está num pacote.
  static ImportLocation? of(RuleContext context) {
    final package = context.package;
    if (package == null) return null;
    final unit = context.currentUnit ?? context.definingUnit;
    final root = package.root.path;
    return ImportLocation._(
      p.basename(root),
      p.posix.joinAll(p.split(p.relative(unit.file.path, from: root))),
    );
  }

  final String packageName;

  /// O arquivo, relativo à raiz do pacote.
  final String file;

  /// O alvo de [directive] dentro do mesmo pacote, relativo à raiz dele, ou
  /// `null` quando o alvo é de outro pacote ou de `dart:`.
  String? targetInPackage(NamespaceDirective directive) {
    final uri = directive.uri.stringValue;
    if (uri == null) return null;
    final ownPrefix = 'package:$packageName/';
    if (uri.startsWith(ownPrefix)) {
      return 'lib/${uri.substring(ownPrefix.length)}';
    }
    if (uri.contains(':')) return null;
    return p.posix.normalize(p.posix.join(p.posix.dirname(file), uri));
  }

  /// O pacote de um import `package:`, ou `null`.
  static String? packageOf(NamespaceDirective directive) {
    final uri = directive.uri.stringValue;
    if (uri == null || !uri.startsWith('package:')) return null;
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    return slash < 0 ? rest : rest.substring(0, slash);
  }
}
