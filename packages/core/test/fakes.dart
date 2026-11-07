import 'dart:async';

import 'package:core/core.dart';

/// Simulações escritas à mão: o core não depende de nenhum pacote, nem de
/// bibliotecas de mock.
final class FakeLogger implements AppLogger {
  final errors = <String>[];

  @override
  void log(String message) {}

  @override
  void error(String reason, Object error, StackTrace stackTrace) =>
      errors.add(reason);

  @override
  void fatal(Object error, StackTrace stackTrace) {}

  @override
  void setUserId(String? opaqueId) {}
}

final class FakeOutbox implements SyncableOutbox {
  FakeOutbox(this.name, {this.result = false, this.throws, this.pending = 0});

  @override
  final String name;
  final bool result;
  final Object? throws;
  final int pending;
  var calls = 0;

  @override
  Future<int> pendingCount() async => pending;

  @override
  Future<bool> sync() async {
    calls++;
    await Future<void>.delayed(Duration.zero);
    if (throws case final error?) throw error;
    return result;
  }
}

final class FakeCleaner implements ClearableOnLogout {
  FakeCleaner({this.throws});

  final Object? throws;
  var cleared = false;

  @override
  Future<void> clearLocalData() async {
    await Future<void>.delayed(Duration.zero);
    cleared = true;
    if (throws case final error?) throw error;
  }
}

final class FakeMonitor implements NetworkInterfaceMonitor {
  FakeMonitor({this.hasInterface = true});

  bool hasInterface;
  final changes = StreamController<bool>.broadcast();

  @override
  Future<bool> hasNetworkInterface() async => hasInterface;

  @override
  Stream<bool> get networkInterfaceChanges => changes.stream;
}

final class FakeProbe implements ReachabilityProbe {
  FakeProbe({this.reachable = true});

  bool reachable;
  var calls = 0;

  @override
  Future<bool> isBackendReachable() async {
    calls++;
    return reachable;
  }
}
