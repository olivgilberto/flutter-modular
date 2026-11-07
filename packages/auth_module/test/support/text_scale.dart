import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// As escalas da fonte do sistema em que toda View é conferida (capítulo
/// 39): a padrão, o máximo do Android (200%) e perto do maior tamanho de
/// acessibilidade do iOS.
const systemTextScales = [1.0, 2.0, 3.0];

/// Põe o teste num telefone pequeno, de 375 × 667 pontos (o iPhone SE),
/// com a fonte do sistema em [scale]. O MaterialApp lê a escala da
/// plataforma, como no aparelho; nenhuma View recebe a escala de fora.
void useSmallPhone(WidgetTester tester, {required double textScale}) {
  tester.view
    ..physicalSize = const Size(750, 1334)
    ..devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Rola até [finder] e confere que ele cabe inteiro na tela: uma ação que
/// existe mas fica fora do alcance é o defeito que a fonte grande produz.
Future<void> expectReachable(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  final screen =
      Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  final rect = tester.getRect(finder);
  expect(
    screen.contains(rect.topLeft) &&
        screen.contains(rect.bottomRight - const Offset(0.01, 0.01)),
    isTrue,
    reason: '$finder em $rect, fora de $screen',
  );
}
