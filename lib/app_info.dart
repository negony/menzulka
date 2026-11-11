/// Сведения о приложении, отображаемые в окне «О программе».
class AppInfo {
  const AppInfo._();

  static const String name = 'Мензулка';
  static const String tagline = 'Электронный абрис для геодезиста';
  static const String description =
      'Чертёж DXF, точки с фото и заметками, измерения, координаты, '
      'рисование на плане и на фотографии — офлайн, на телефоне и компьютере.';

  /// Ссылка на исходный код.
  static const String githubUrl = 'https://github.com/negony/menzulka';

  /// Человекочитаемая строка версии: «1.16.2 (сборка 48)».
  static String versionLabel(String version, String buildNumber) {
    if (version.isEmpty && buildNumber.isEmpty) return '—';
    if (buildNumber.isEmpty) return version;
    return '$version (сборка $buildNumber)';
  }
}
