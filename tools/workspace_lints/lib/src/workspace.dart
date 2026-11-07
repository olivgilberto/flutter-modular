import 'dart:io';

import 'package:yaml/yaml.dart';

final class Package {
  const Package({
    required this.name,
    required this.path,
    required this.dependencies,
  });

  final String name;

  /// Caminho relativo à raiz, como está na lista workspace:.
  final String path;

  /// Só a seção dependencies; dev_dependencies não cruzam fronteiras.
  final Set<String> dependencies;
}

final class Workspace {
  const Workspace({required this.project, required this.packages});

  /// O name: do pubspec.yaml raiz, que dá nome ao host ([project]_app).
  final String project;
  final List<Package> packages;

  Set<String> get toolNames => {
    for (final p in packages)
      if (p.path.startsWith('tools/')) p.name,
  };

  static Workspace read(Directory root) {
    final pubspec = _load('${root.path}/pubspec.yaml');
    final members = (pubspec['workspace'] as List?)?.cast<String>() ?? const [];
    return Workspace(
      project: pubspec['name'] as String,
      packages: [
        for (final path in members)
          _package(path, _load('${root.path}/$path/pubspec.yaml')),
      ],
    );
  }

  static YamlMap _load(String path) =>
      loadYaml(File(path).readAsStringSync()) as YamlMap;

  static Package _package(String path, YamlMap pubspec) => Package(
    name: pubspec['name'] as String,
    path: path,
    dependencies: {
      ...?(pubspec['dependencies'] as YamlMap?)?.keys.cast<String>(),
    },
  );
}
