/// Portas e código sem tecnologia do mobile_tarefas.
library;

export 'src/api_client.dart' show ApiClient, ApiError, ApiErrorKind;
export 'src/app_analytics.dart' show AppAnalytics;
export 'src/app_logger.dart' show AppLogger;
export 'src/app_preferences.dart' show AppPreferences, AppThemeMode;
export 'src/connectivity.dart'
    show
        ConnectivityService,
        ConnectivityStatus,
        NetworkInterfaceMonitor,
        ReachabilityProbe;
export 'src/connectivity_reporting_api_client.dart'
    show ConnectivityReportingApiClient;
export 'src/default_connectivity_service.dart' show DefaultConnectivityService;
export 'src/failure.dart' show Failure;
export 'src/local_database.dart'
    show
        DatabaseSchema,
        LocalDatabase,
        LocalDatabaseError,
        LocalDatabaseFactory;
export 'src/logout.dart'
    show ClearableOnLogout, DefaultLogoutCleanerRegistry, LogoutCleanerRegistry;
export 'src/outbox.dart'
    show DefaultOutboxRegistry, OutboxRegistry, SyncableOutbox;
export 'src/outbox_sync_worker.dart' show OutboxSyncWorker;
export 'src/sync_orchestrator.dart' show SyncOrchestrator;
export 'src/sync_scheduler.dart' show SyncScheduler;
export 'src/token_provider.dart' show TokenProvider;
