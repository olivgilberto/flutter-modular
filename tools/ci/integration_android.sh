#!/usr/bin/env bash
# Os testes de integração no emulador do CI (capítulo 40), com as mesmas
# regras do verificar_integracao.sh do capítulo 39: as duas portas do
# dev_backend ligadas pelo adb reverse e cada arquivo num app instalado do
# zero. Um arquivo que falha não impede os outros; o script sai com 1 no
# fim se algum falhou.
set -u
cd "$(dirname "$0")/../../mobile_tarefas_app"
adb reverse tcp:8080 tcp:8080
adb reverse tcp:8081 tcp:8081
status=0
for f in integration_test/*_test.dart; do
  adb uninstall com.zayitbrazil.mobiletarefas.dev > /dev/null 2>&1 || true
  echo "::group::$f"
  flutter test "$f" -d emulator-5554 --flavor dev \
    --dart-define-from-file=config/dev_local.json || status=1
  echo "::endgroup::"
done
exit $status
