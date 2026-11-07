import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('só falhas de rede e do servidor são transitórias', () {
    expect(const ApiError(ApiErrorKind.unreachable).isTransient, isTrue);
    expect(const ApiError(ApiErrorKind.server).isTransient, isTrue);
    expect(const ApiError(ApiErrorKind.rejected).isTransient, isFalse);
    expect(const ApiError(ApiErrorKind.invalidResponse).isTransient, isFalse);
  });
}
