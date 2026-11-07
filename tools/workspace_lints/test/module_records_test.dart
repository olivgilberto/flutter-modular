import 'package:test/test.dart';
import 'package:workspace_lints/workspace_lints.dart';

Package pkg(String name) =>
    Package(name: name, path: 'packages/$name', dependencies: const {});

final workspace = [pkg('core'), pkg('auth_module'), pkg('tasks_module')];

const owners = '''
# Donos por módulo (capítulo 42)
*                       @plataforma
/packages/auth_module/  @time-conta
/packages/tasks_module/ @time-tarefas
''';

const index = '''
## Módulos
- [auth_module](modules/auth_module.md)
- [tasks_module](modules/tasks_module.md)
''';

ModuleRecords records({
  Set<String> docs = const {'auth_module', 'tasks_module'},
  String architecture = index,
  String codeOwners = owners,
}) => ModuleRecords(
  moduleDocs: docs,
  architecture: architecture,
  codeOwners: parseCodeOwners(codeOwners),
);

List<String> check(ModuleRecords r, [List<Package>? packages]) =>
    moduleRecordViolations(packages ?? workspace, 'mobile_tarefas', r);

void main() {
  test('módulos com página, índice e dono passam', () {
    expect(check(records()), isEmpty);
  });

  test('um módulo novo sem nada aparece três vezes', () {
    final found = check(records(), [...workspace, pkg('notes_module')]);
    expect(found, hasLength(3));
    expect(found, everyElement(startsWith('notes_module: ')));
  });

  test('a página precisa estar no índice da arquitetura', () {
    final found = check(
      records(architecture: '- [auth_module](modules/auth_module.md)'),
    );
    expect(found, [
      'tasks_module: o docs/architecture.md não aponta para '
          'modules/tasks_module.md',
    ]);
  });

  test('uma página sem módulo é recusada', () {
    final found = check(
      records(docs: {'auth_module', 'tasks_module', 'cart_module'}),
    );
    expect(found, [
      'docs/modules/cart_module.md: não há módulo cart_module no '
          'workspace',
    ]);
  });

  test('o dono geral não basta: cada módulo tem a sua linha', () {
    final found = check(
      records(codeOwners: '* @plataforma\n/packages/auth_module/ @time-conta'),
    );
    expect(found, hasLength(1));
    expect(found.single, startsWith('tasks_module: sem linha própria'));
  });

  test('vale a última linha que alcança o módulo, como no GitHub', () {
    final found = check(records(codeOwners: '$owners\n/packages/ @plataforma'));
    expect(found, hasLength(2));
  });

  test('uma linha sem dono é recusada', () {
    final found = check(
      records(
        codeOwners:
            '/packages/auth_module/ @time-conta\n'
            '/packages/tasks_module/',
      ),
    );
    expect(found, [
      'tasks_module: a linha /packages/tasks_module/ do CODEOWNERS não tem dono',
    ]);
  });

  test('o parse ignora comentários e linhas vazias', () {
    expect(parseCodeOwners(owners).map((r) => r.pattern), [
      '*',
      '/packages/auth_module/',
      '/packages/tasks_module/',
    ]);
    expect(parseCodeOwners(owners).last.owners, ['@time-tarefas']);
  });
}
