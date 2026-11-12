/// Ошибка конвертации CAD-файла: код нативного слоя + человекочитаемое сообщение.
class CadConversionException implements Exception {
  const CadConversionException(this.code, this.message);

  /// Код ошибки (см. `native/src/lib.rs`, `ErrorCode`).
  final int code;

  /// Текст ошибки для пользователя/лога.
  final String message;

  /// Нативная библиотека недоступна в этой сборке.
  static const int codeUnavailable = -1;

  /// Пользователь отменил ожидание (таймаут).
  static const int codeTimeout = 6;

  /// Не удалось записать DWG.
  static const int codeWriteFailed = 6;

  /// Чертёж содержит объекты, которые нельзя записать в DWG.
  static const int codeWriteUnsupported = 7;

  bool get isUnavailable => code == codeUnavailable;

  /// Файл новее поддерживаемого формата (новейший — R2018 / AC1032).
  bool get isUnsupportedVersion => code == 2;

  /// Файл повреждён или не является DWG.
  bool get isCorrupt => code == 3 || code == 1;

  /// Файл защищён паролем/шифрованием.
  bool get isEncrypted => code == 4;

  bool get isTimeout => code == codeTimeout;

  /// Ошибка записи DWG (а не чтения).
  bool get isWriteFailed => code == codeWriteFailed;

  /// В чертеже есть объекты, которые нельзя записать в DWG.
  bool get isWriteUnsupported => code == codeWriteUnsupported;

  @override
  String toString() => 'CadConversionException($code): $message';
}
