import 'dart:math';

/// Um UUID versão 4 (RFC 9562): 122 bits aleatórios de `Random.secure()`,
/// com os bits de versão e de variante no lugar. Dez linhas no lugar de
/// mais uma dependência. É o id das tarefas, gerado no aparelho, e o das
/// operações da fila de envio (capítulo 31).
String newUuidV4([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versão 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante 10xx
  final hex = [
    for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
