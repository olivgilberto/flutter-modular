# adapter_connectivity_connectivity_plus

A camada 1 da conectividade (existe alguma interface de rede?), com
connectivity_plus.

- **Contém:** `ConnectivityPlusNetworkInterfaceMonitor` (porta
  `NetworkInterfaceMonitor`).
- **Nunca contém:** a pergunta "o backend responde?" (é a
  `HttpReachabilityProbe`) nem a decisão de quando sincronizar (é o
  `SyncOrchestrator` do core).
