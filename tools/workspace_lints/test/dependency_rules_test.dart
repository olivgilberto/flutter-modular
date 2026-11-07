import 'package:test/test.dart';
import 'package:workspace_lints/workspace_lints.dart';

Package pkg(String name, List<String> deps, {String? path}) => Package(
  name: name,
  path: path ?? 'packages/$name',
  dependencies: deps.toSet(),
);

List<String> check(Package p) =>
    violations(p, 'mobile_tarefas', {'workspace_lints'});

void main() {
  test('um módulo não declara outro módulo', () {
    expect(check(pkg('tasks_module', ['core', 'auth_module'])), hasLength(1));
  });

  test('o core não declara nada', () {
    expect(check(pkg('core', ['meta'])), hasLength(1));
    expect(check(pkg('core', [])), isEmpty);
  });

  test('um módulo não contorna uma porta', () {
    expect(check(pkg('tasks_module', ['core', 'http'])), hasLength(1));
    expect(
      check(pkg('tasks_module', ['core', 'firebase_analytics'])),
      hasLength(1),
    );
  });

  test('toda tecnologia de uma família de adaptador é abstraída pelo core '
      '(capítulo 36)', () {
    for (final dep in adapterFamilies.values.expand((family) => family)) {
      expect(
        check(pkg('tasks_module', ['core', dep])),
        hasLength(1),
        reason: dep,
      );
    }
    // As que o módulo usa de fato continuam permitidas.
    expect(
      check(
        pkg('tasks_module', [
          'core',
          'design_system',
          'flutter',
          'get_it',
          'flutter_bloc',
          'bloc_concurrency',
          'go_router',
        ]),
      ),
      isEmpty,
    );
  });

  test('uma tecnologia aposentada continua fora dos módulos (capítulo 41)', () {
    expect(adapterFamilies.values.any((f) => f.contains('dio')), isFalse);
    expect(check(pkg('tasks_module', ['core', 'dio'])), hasLength(1));
  });

  test('um adaptador fica na sua família', () {
    expect(check(pkg('adapter_http_http', ['core', 'http'])), isEmpty);
    expect(
      check(pkg('adapter_http_http', ['core', 'http', 'get_it'])),
      hasLength(1),
    );
    expect(check(pkg('adapter_http_http', ['core', 'dio'])), hasLength(1));
    expect(check(pkg('adapter_cache_hive', ['core', 'hive'])), hasLength(1));
  });

  test('nome sem papel é recusado', () {
    expect(check(pkg('common', [])), hasLength(1));
  });

  test('o host pode depender de tudo', () {
    expect(
      check(
        pkg('mobile_tarefas_app', [
          'core',
          'tasks_module',
          'adapter_http_http',
        ]),
      ),
      isEmpty,
    );
  });

  test('ferramentas nunca são dependência', () {
    expect(check(pkg('mobile_tarefas_app', ['workspace_lints'])), hasLength(1));
  });
}
