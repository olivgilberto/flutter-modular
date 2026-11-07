import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core/core.dart';

/// [NetworkInterfaceMonitor] com connectivity_plus. Responde só "existe
/// alguma interface de rede?"; se a internet responde é com a
/// [ReachabilityProbe]. `ConnectivityResult` nunca sai desta classe.
final class ConnectivityPlusNetworkInterfaceMonitor
    implements NetworkInterfaceMonitor {
  ConnectivityPlusNetworkInterfaceMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> hasNetworkInterface() async {
    try {
      return _hasInterface(await _connectivity.checkConnectivity());
    } on Exception {
      // Falha do plugin: supõe que há interface e deixa a sonda decidir.
      return true;
    }
  }

  @override
  Stream<bool> get networkInterfaceChanges =>
      _connectivity.onConnectivityChanged.map(_hasInterface).distinct();

  static bool _hasInterface(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
