enum ConnectivityStatus {
  /// Ainda não verificado (boot): nem aviso, nem sincronização.
  unknown,

  /// Nenhuma interface de rede (modo avião, Wi-Fi e dados desligados).
  offline,

  /// Há interface, mas o backend não responde (Wi-Fi sem internet,
  /// portal cativo).
  noInternet,

  /// O backend responde.
  online,
}

/// Camada 1: existe alguma interface de rede? Barata, guiada por eventos
/// do sistema; não diz nada sobre a internet.
abstract interface class NetworkInterfaceMonitor {
  Future<bool> hasNetworkInterface();

  /// Emite sempre que a disponibilidade de interface muda.
  Stream<bool> get networkInterfaceChanges;
}

/// Camada 2: o backend responde? Qualquer resposta HTTP conta como
/// alcançável; só falhas de transporte não contam. Nunca lança.
abstract interface class ReachabilityProbe {
  Future<bool> isBackendReachable();
}

/// Combina as duas camadas num [ConnectivityStatus], para o aviso do host e
/// para o [SyncOrchestrator]. É só uma dica: nenhuma ação é bloqueada por
/// causa dele.
abstract interface class ConnectivityService {
  ConnectivityStatus get status;
  Stream<ConnectivityStatus> get statusChanges;

  /// Começa a ouvir as mudanças de interface e verifica uma vez. Nunca é
  /// aguardado no boot, porque pode ir à rede.
  Future<void> start();

  /// Reavalia as duas camadas agora.
  Future<ConnectivityStatus> check();

  Future<void> dispose();
}
