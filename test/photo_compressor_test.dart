import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:menzulka/utils/photo_compressor.dart';
import 'package:image/image.dart' as img;

void main() {
  test('сжимает большое изображение и уменьшает длинную сторону', () {
    final image = img.Image(width: 2400, height: 1600);
    img.fill(image, color: img.ColorRgb8(50, 120, 200));
    img.noise(image, 10);
    final original = Uint8List.fromList(img.encodeJpg(image, quality: 95));

    final compressed = compressPhotoBytes(original, maxSide: 1600, quality: 80);

    expect(compressed.length, lessThan(original.length));
    final decoded = img.decodeImage(compressed);
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(1600));
    expect(decoded.height, lessThanOrEqualTo(1600));
    expect(isJpegBytes(compressed), isTrue);
  });

  test('возвращает исходник для невалидных данных', () {
    final garbage = Uint8List.fromList(List<int>.generate(64, (i) => i));
    expect(compressPhotoBytes(garbage), equals(garbage));
  });

  test('isJpegBytes распознаёт JPEG-сигнатуру', () {
    final image = img.Image(width: 8, height: 8);
    final jpeg = Uint8List.fromList(img.encodeJpg(image));
    expect(isJpegBytes(jpeg), isTrue);
    expect(isJpegBytes(Uint8List.fromList([1, 2, 3])), isFalse);
  });
}
