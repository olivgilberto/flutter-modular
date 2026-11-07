/// Implementado por cada módulo que guarda dados locais da sessão.
abstract interface class ClearableOnLogout {
  Future<void> clearLocalData();
}

abstract interface class LogoutCleanerRegistry {
  void register(ClearableOnLogout cleaner);

  /// Roda todos os cleaners registrados. Um cleaner que falhe não
  /// impede os outros; depois que todos terminam, a primeira falha
  /// é relançada.
  Future<void> clearAll();

  /// Esquece os cleaners da sessão que terminou.
  void unregisterAll();
}

final class DefaultLogoutCleanerRegistry implements LogoutCleanerRegistry {
  final List<ClearableOnLogout> _cleaners = [];

  @override
  void register(ClearableOnLogout cleaner) => _cleaners.add(cleaner);

  /// `Future.wait`, e não o `.wait` das listas: o `.wait` reúne as falhas
  /// num `ParallelWaitError`, que é um `Error` e seria tratado como bug.
  @override
  Future<void> clearAll() async {
    await Future.wait([
      for (final cleaner in List.of(_cleaners)) cleaner.clearLocalData(),
    ]);
  }

  @override
  void unregisterAll() => _cleaners.clear();
}
