import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';

/// Окно «О программе»: название, версия сборки и ссылка на исходный код.
class AboutAppDialog extends StatefulWidget {
  const AboutAppDialog({super.key, this.infoLoader});

  /// Загрузка сведений о сборке; в тестах подменяется, чтобы не зависеть
  /// от платформенного плагина.
  final Future<PackageInfo> Function()? infoLoader;

  @override
  State<AboutAppDialog> createState() => _AboutAppDialogState();
}

class _AboutAppDialogState extends State<AboutAppDialog> {
  late final Future<PackageInfo> _info =
      (widget.infoLoader ?? PackageInfo.fromPlatform)();

  Future<void> _openGithub(BuildContext context) async {
    final uri = Uri.parse(AppInfo.githubUrl);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      await Clipboard.setData(const ClipboardData(text: AppInfo.githubUrl));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка скопирована в буфер обмена')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('about-dialog'),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(Icons.terrain,
                  size: 38, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              AppInfo.name,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              AppInfo.tagline,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FutureBuilder<PackageInfo>(
              future: _info,
              builder: (context, snapshot) {
                final info = snapshot.data;
                final label = info == null
                    ? (snapshot.hasError ? '—' : '…')
                    : AppInfo.versionLabel(info.version, info.buildNumber);
                return Column(
                  key: const Key('about-version'),
                  children: [
                    Text('Версия $label', style: theme.textTheme.titleSmall),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              AppInfo.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code),
              title: const Text('Исходный код'),
              subtitle: Text(AppInfo.githubUrl,
                  key: const Key('about-github-url'),
                  style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openGithub(context),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('about-copy-link'),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Копировать ссылку',
                    style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: AppInfo.githubUrl));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ссылка скопирована')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('about-close'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
