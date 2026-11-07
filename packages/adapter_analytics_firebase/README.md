# adapter_analytics_firebase

Os eventos de produto do projeto, com Google Analytics for Firebase.

- **Contém:** `FirebaseAppAnalytics` (porta `AppAnalytics`), que nunca
  lança: uma falha do plugin vai para o `AppLogger`.
- **Nunca contém:** registro de falhas (é o `AppLogger`), dados pessoais
  em nomes ou parâmetros, nem a decisão de consentimento (fica no host).
