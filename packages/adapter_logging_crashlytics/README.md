# adapter_logging_crashlytics

O registro de falhas do projeto, com Firebase Crashlytics.

- **Contém:** `CrashlyticsAppLogger` (porta `AppLogger`). Enquanto o
  Firebase não está inicializado, escreve no console; não existe um
  adaptador de console separado.
- **Nunca contém:** eventos de produto (esses vão para o `AppAnalytics`),
  a inicialização do Firebase nem os handlers globais de erro (ficam no
  host).
