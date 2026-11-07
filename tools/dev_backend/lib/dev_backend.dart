/// Um backend em memória que fala o contrato do mobile_tarefas, para rodar
/// o app no simulador sem servidor de verdade (capítulo 35). Só para
/// desenvolvimento: escuta na interface local, guarda tudo em memória e
/// esquece tudo ao parar.
library;

export 'src/dev_backend_state.dart' show DevBackendState, DevRejection;
export 'src/api_port.dart' show ApiPort;
export 'src/control_handler.dart' show controlHandler;
export 'src/dev_backend_handler.dart' show devBackendHandler;
