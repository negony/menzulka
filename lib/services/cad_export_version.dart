/// Целевые версии DWG для экспорта (самые распространённые).
enum DwgExportVersion {
  /// AutoCAD 2018+ (AC1032).
  r2018,

  /// AutoCAD 2013+ (AC1027).
  r2013,

  /// AutoCAD 2007+ (AC1021).
  r2007,
}

extension DwgExportVersionInfo on DwgExportVersion {
  /// Подпись для интерфейса.
  String get label => switch (this) {
        DwgExportVersion.r2018 => '2018',
        DwgExportVersion.r2013 => '2013',
        DwgExportVersion.r2007 => '2007',
      };

  /// Код версии в файле DWG.
  String get code => switch (this) {
        DwgExportVersion.r2018 => 'AC1032',
        DwgExportVersion.r2013 => 'AC1027',
        DwgExportVersion.r2007 => 'AC1021',
      };

  /// Биты флагов нативного слоя (см. `FLAG_DWG_VERSION_*`).
  int get flagBits => switch (this) {
        DwgExportVersion.r2018 => 0,
        DwgExportVersion.r2013 => 1,
        DwgExportVersion.r2007 => 2,
      };

  /// Подпись для диалога: «DWG 2018 (R2018)».
  String get dialogLabel => 'DWG $label';
}
