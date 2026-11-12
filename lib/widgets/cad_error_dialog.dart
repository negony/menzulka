/// Диалог ошибки чтения DWG: объясняет причину и подсказывает, что делать.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../services/cad_conversion_exception.dart';

class CadErrorDialog extends StatelessWidget {
  const CadErrorDialog({super.key, required this.error, this.fileName});

  final CadConversionException error;
  final String? fileName;

  static Future<void> show(
    BuildContext context,
    CadConversionException error, {
    String? fileName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => CadErrorDialog(error: error, fileName: fileName),
    );
  }

  String get _title {
    if (error.isUnavailable) return 'Модуль DWG недоступен';
    if (error.isUnsupportedVersion) return 'Формат DWG новее поддерживаемого';
    if (error.isEncrypted) return 'Чертёж защищён паролем';
    if (error.isTimeout) return 'Превышено время чтения DWG';
    if (error.isCorrupt) return 'Не удалось прочитать DWG';
    return 'Ошибка чтения DWG';
  }

  String get _reason {
    if (error.isUnavailable) {
      return 'В этой сборке нет модуля чтения DWG. Файлы DXF открываются как обычно.\n\n'
          'Проверьте, что приложение установлено из официального установщика '
          '(Windows) или APK (Android).';
    }
    if (error.isUnsupportedVersion) {
      return 'Поддерживаются DWG от R12 до R2018 (AC1009–AC1032).\n\n'
          'Откройте чертёж в AutoCAD и сохраните его в формате '
          '«AutoCAD 2018 Drawing (*.dwg)» или сразу в DXF.';
    }
    if (error.isEncrypted) {
      return 'Файл зашифрован или защищён паролем. Снимите защиту в AutoCAD '
          'и сохраните копию без пароля.';
    }
    if (error.isTimeout) {
      return 'Файл слишком большой или сложный. Попробуйте разделить чертёж '
          'или сохранить его в DXF.';
    }
    if (error.isCorrupt) {
      return 'Файл повреждён, имеет нестандартную структуру или не является DWG.\n\n'
          'Попробуйте пересохранить его в AutoCAD, либо обратитесь к источнику файла.';
    }
    return 'Не удалось преобразовать файл в DXF.';
  }

  String get _hint {
    if (Platform.isWindows) {
      return 'Запасной способ: бесплатная программа ODA File Converter '
          '(устанавливается отдельно, в поставку не входит) — '
          'https://www.opendesign.com/guestfiles/oda_file_converter';
    }
    return 'На телефоне DWG удобнее открыть, если заранее сохранить его в DXF '
        'на компьютере и передать в проект.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('cad-error-dialog'),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(_title, style: theme.textTheme.titleMedium)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fileName != null) ...[
              Text(
                fileName!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
            ],
            Text(_reason),
            const SizedBox(height: 12),
            Text(
              _hint,
              key: const Key('cad-error-hint'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Код: ${error.code}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cad-error-close'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Понятно'),
        ),
      ],
    );
  }
}
