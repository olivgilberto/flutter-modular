import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeLocalDatabasesFromBackup()
    registerBackgroundSync()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Capítulo 32: a sincronização das filas com o app fechado. O
  /// identificador é o WorkmanagerSyncScheduler.taskName, o mesmo da chave
  /// BGTaskSchedulerPermittedIdentifiers do Info.plist; a frequência, a do
  /// adaptador. O iOS decide quando rodar: o valor é só o mínimo entre duas
  /// execuções. A tarefa roda num engine próprio, sem os plugins, que
  /// precisam ser registrados nele.
  private func registerBackgroundSync() {
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "outbox_sync",
      frequency: NSNumber(value: 60 * 60)
    )
  }

  /// Capítulo 30: os bancos dos módulos ficam fora do backup do iCloud e do
  /// computador. A pasta é a do SqlcipherLocalDatabaseFactory.directoryName,
  /// dentro do Application Support. A marca vai na pasta, criada aqui se
  /// ainda não existir, e é refeita a cada abertura do app, porque algumas
  /// operações de arquivo a desfazem.
  private func excludeLocalDatabasesFromBackup() {
    let fileManager = FileManager.default
    guard
      var directory = fileManager.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first?.appendingPathComponent("local_databases", isDirectory: true)
    else { return }
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try directory.setResourceValues(values)
    } catch {
      NSLog("local_databases fora do backup: falhou (\(error))")
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
