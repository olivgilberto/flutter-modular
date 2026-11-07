// Os testes do test_reflective_loader são métodos com o prefixo test_,
// que o lint de nomes não aceita.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:workspace_lints/src/rules/layer_imports.dart';

/// Cada linha da tabela do capítulo 15, com um import que viola e outro que
/// não viola. O pacote de teste se chama "test".
void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(LayerImportsTest);
  });
}

@reflectiveTest
class LayerImportsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = LayerImports();
    newPackage('flutter').addFile('lib/widgets.dart', 'class C {}');
    newPackage('flutter_bloc').addFile('lib/flutter_bloc.dart', 'class C {}');
    super.setUp();
    // Os alvos dos imports existem e declaram uma classe, que o arquivo
    // testado usa: nenhum erro de URI nem aviso de import sem uso se
    // mistura ao lint.
    for (final path in [
      'lib/domain/task.dart',
      'lib/application/use_cases/task_use_case.dart',
      'lib/application/ports/task_repository.dart',
      'lib/adapters/driven/task_service.dart',
      'lib/adapters/driving/task_view.dart',
    ]) {
      newFile('$testPackageRootPath/$path', 'class C {}');
    }
  }

  /// Escreve [path] com o [uri] importado e confere o lint (ou nada).
  Future<void> _assert(String path, String uri, {required bool lints}) async {
    final content = "import '$uri' as m;\n\nm.C? c;\n";
    final file = newFile('$testPackageRootPath/$path', content);
    await assertDiagnosticsInFile(file.path, [
      if (lints) lint(content.indexOf("'"), uri.length + 2),
    ]);
  }

  Future<void> test_domain_importsApplication() => _assert(
    'lib/domain/entities/task_list.dart',
    '../../application/use_cases/task_use_case.dart',
    lints: true,
  );

  Future<void> test_domain_importsAdaptersByPackage() => _assert(
    'lib/domain/entities/task_list.dart',
    'package:test/adapters/driven/task_service.dart',
    lints: true,
  );

  Future<void> test_domain_importsFlutter() => _assert(
    'lib/domain/entities/task_list.dart',
    'package:flutter/widgets.dart',
    lints: true,
  );

  Future<void> test_domain_importsDomain() => _assert(
    'lib/domain/entities/task_list.dart',
    '../task.dart',
    lints: false,
  );

  Future<void> test_application_importsAdapters() => _assert(
    'lib/application/use_cases/other.dart',
    '../../adapters/driven/task_service.dart',
    lints: true,
  );

  Future<void> test_application_importsFlutterPackage() => _assert(
    'lib/application/use_cases/other.dart',
    'package:flutter_bloc/flutter_bloc.dart',
    lints: true,
  );

  Future<void> test_application_importsDomain() => _assert(
    'lib/application/use_cases/other.dart',
    '../../domain/task.dart',
    lints: false,
  );

  Future<void> test_driving_importsDriven() => _assert(
    'lib/adapters/driving/bloc/task_bloc.dart',
    '../../driven/task_service.dart',
    lints: true,
  );

  Future<void> test_driving_importsPorts() => _assert(
    'lib/adapters/driving/bloc/task_bloc.dart',
    '../../../application/ports/task_repository.dart',
    lints: true,
  );

  Future<void> test_driving_importsUseCase() => _assert(
    'lib/adapters/driving/bloc/task_bloc.dart',
    '../../../application/use_cases/task_use_case.dart',
    lints: false,
  );

  Future<void> test_driven_importsDriving() => _assert(
    'lib/adapters/driven/services/other.dart',
    'package:test/adapters/driving/task_view.dart',
    lints: true,
  );

  Future<void> test_driven_importsPorts() => _assert(
    'lib/adapters/driven/services/other.dart',
    '../../../application/ports/task_repository.dart',
    lints: false,
  );

  Future<void> test_entryFile_importsEverything() => _assert(
    'lib/test.dart',
    'adapters/driven/task_service.dart',
    lints: false,
  );
}
