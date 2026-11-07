// Os testes do test_reflective_loader são métodos com o prefixo test_,
// que o lint de nomes não aceita.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:workspace_lints/src/rules/get_it_outside_edges.dart';

/// Um arquivo que viola e outros que não violam (capítulo 15). O pacote de
/// teste se chama "test", e o arquivo de entrada dele é lib/test.dart.
void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(GetItOutsideEdgesTest);
  });
}

/// O import usado de verdade, para que o aviso de import sem uso não se
/// misture ao lint.
const _import = "import 'package:get_it/get_it.dart' as di;\n\ndi.C? c;\n";

@reflectiveTest
class GetItOutsideEdgesTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = GetItOutsideEdges();
    newPackage('get_it').addFile('lib/get_it.dart', 'class C {}');
    super.setUp();
  }

  /// Escreve [path] com o import do get_it e confere o lint (ou nada).
  Future<void> _assert(String path, {required bool lints}) async {
    final file = newFile('$testPackageRootPath/$path', _import);
    await assertDiagnosticsInFile(file.path, [
      if (lints)
        lint(_import.indexOf("'"), "'package:get_it/get_it.dart'".length),
    ]);
  }

  Future<void> test_domain_violates() =>
      _assert('lib/domain/task.dart', lints: true);

  Future<void> test_view_violates() =>
      _assert('lib/adapters/driving/views/task_view.dart', lints: true);

  Future<void> test_entryFile_isEdge() =>
      _assert('lib/test.dart', lints: false);

  Future<void> test_page_isEdge() =>
      _assert('lib/adapters/driving/pages/task_page.dart', lints: false);

  Future<void> test_hostBootstrap_isEdge() =>
      _assert('lib/bootstrap/dependency_injection.dart', lints: false);

  Future<void> test_tests_areEdges() =>
      _assert('test/task_test.dart', lints: false);
}
