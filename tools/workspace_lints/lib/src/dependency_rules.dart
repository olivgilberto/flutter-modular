import 'workspace.dart';

enum Role { core, designSystem, adapter, module, app, tool }

/// O papel vem do nome (seção 15.4). Null: o nome não declara papel.
Role? roleOf(String name, String path, String project) => switch (name) {
  _ when path.startsWith('tools/') => Role.tool,
  'core' => Role.core,
  'design_system' => Role.designSystem,
  _ when name == '${project}_app' => Role.app,
  _ when name.startsWith('adapter_') => Role.adapter,
  _ when name.endsWith('_module') => Role.module,
  _ => null,
};

/// A família de tecnologia de cada adaptador. Um adaptador novo só
/// passa depois de entrar aqui, no mesmo pull request que o cria.
const adapterFamilies = {
  'adapter_http_http': {'http'},
  'adapter_db_sqlcipher': {
    'sqflite_sqlcipher',
    'flutter_secure_storage',
    'path_provider',
  },
  'adapter_logging_crashlytics': {'firebase_core', 'firebase_crashlytics'},
  'adapter_analytics_firebase': {'firebase_core', 'firebase_analytics'},
  'adapter_sync_workmanager': {'workmanager'},
  'adapter_prefs_shared_preferences': {'shared_preferences'},
  'adapter_connectivity_connectivity_plus': {'connectivity_plus'},
};

/// Tecnologias que o core abstrai: um módulo nunca as declara. São as das
/// famílias dos adaptadores, sem uma segunda lista para esquecer alguém: a
/// lista escrita à mão, até o capítulo 36, deixava passar o
/// `flutter_secure_storage` e o `path_provider`.
bool isAbstracted(String dep) =>
    adapterFamilies.values.any((family) => family.contains(dep)) ||
    retiredTechnologies.contains(dep) ||
    dep.startsWith('firebase_');

/// Tecnologias de adaptadores que saíram do workspace. Com o adaptador, sai
/// a família, e a tecnologia deixaria de ser recusada num módulo: o Dio,
/// trocado pelo pacote http no capítulo 41, continua fora dos módulos.
const retiredTechnologies = {'dio'};

List<String> violations(Package p, String project, Set<String> tools) {
  final found = <String>[];
  void forbid(bool Function(String dep) rule, String why) {
    for (final dep in p.dependencies.where(rule)) {
      found.add('${p.name} depende de $dep: $why');
    }
  }

  bool isModule(String d) => d.endsWith('_module');
  bool isAdapter(String d) => d.startsWith('adapter_');

  forbid(tools.contains, 'ferramentas nunca são dependência');
  switch (roleOf(p.name, p.path, project)) {
    case null:
      found.add('${p.name}: o nome não declara o papel do pacote');
    case Role.core:
      forbid((_) => true, 'o core só depende do SDK');
    case Role.designSystem:
      forbid(
        (d) => d == 'core' || isModule(d) || isAdapter(d),
        'o design_system não conhece portas nem features',
      );
    case Role.adapter:
      final family = adapterFamilies[p.name];
      if (family == null) {
        found.add('${p.name}: adaptador sem família de tecnologia registrada');
      } else {
        forbid(
          (d) => d != 'core' && d != 'flutter' && !family.contains(d),
          'fora da família de tecnologia do adaptador',
        );
      }
    case Role.module:
      forbid(
        (d) => isModule(d) || isAdapter(d) || isAbstracted(d),
        'um módulo só alcança outras tecnologias pelas portas do core',
      );
    case Role.app || Role.tool:
      break;
  }
  return found;
}
