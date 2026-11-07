import 'dart:math';

import 'package:flutter/painting.dart';

/// A razão de contraste das WCAG 2.2 entre duas cores, de 1 a 21.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// O mínimo do nível AA para texto comum.
const aaNormalText = 4.5;
