import 'package:flutter_test/flutter_test.dart';

import 'package:menzulka/utils/format_utils.dart';

void main() {
  test('formatCoordinate: 3 знака, группы тысяч, минус', () {
    expect(formatCoordinate(0), '0.000');
    expect(formatCoordinate(2), '2.000');
    expect(formatCoordinate(2217.5689), '2 217.569');
    expect(formatCoordinate(-12.3), '-12.300');
    expect(formatCoordinate(1234567.8912), '1 234 567.891');
    expect(formatCoordinate(-0.0004), '0.000');
  });
}
