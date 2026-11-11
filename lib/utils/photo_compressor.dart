import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// Параметры сжатия фотографии при экспорте пакета.
class PhotoCompressionOptions {
  final int maxSide;
  final int quality;
  const PhotoCompressionOptions({
    this.maxSide = 1600,
    this.quality = 80,
  });

  /// Компактный режим: длинная сторона до 1600 px, JPEG 80.
  static const compact = PhotoCompressionOptions();
}

/// true, если байты начинаются с JPEG-сигнатуры (SOI).
bool isJpegBytes(Uint8List data) =>
    data.length > 2 && data[0] == 0xFF && data[1] == 0xD8;

/// Сжимает изображение: длинную сторону уменьшает до [maxSide], перекодирует
/// в JPEG с [quality]. При ошибке декодирования или если результат не меньше
/// исходника — возвращает исходные байты.
Uint8List compressPhotoBytes(
  Uint8List input, {
  int maxSide = 1600,
  int quality = 80,
}) {
  try {
    final decoded = img.decodeImage(input);
    if (decoded == null) return input;

    var image = decoded;
    final longSide = math.max(decoded.width, decoded.height);
    if (longSide > maxSide) {
      final scale = maxSide / longSide;
      final width = math.max(1, (decoded.width * scale).round());
      final height = math.max(1, (decoded.height * scale).round());
      image = img.copyResize(
        decoded,
        width: width,
        height: height,
        interpolation: img.Interpolation.average,
      );
    } else {
      // явно разворачиваем EXIF-поворот, иначе фото окажется боком
      image = img.bakeOrientation(decoded);
    }

    final encoded = img.encodeJpg(image, quality: quality);
    if (encoded.length >= input.length) return input;
    return encoded;
  } catch (_) {
    return input;
  }
}

/// Сжатие в отдельном изоляте, чтобы не блокировать UI.
Future<Uint8List> compressPhotoAsync(
  Uint8List input, {
  PhotoCompressionOptions options = PhotoCompressionOptions.compact,
}) {
  return compute(
    compressPhotoInIsolate,
    <String, Object>{
      'bytes': input,
      'maxSide': options.maxSide,
      'quality': options.quality,
    },
  );
}

/// Top-level обёртка для [compute] (должна быть top-level или static).
Uint8List compressPhotoInIsolate(Map<String, Object> args) {
  return compressPhotoBytes(
    args['bytes'] as Uint8List,
    maxSide: args['maxSide'] as int,
    quality: args['quality'] as int,
  );
}
