import 'package:flutter/material.dart';
import '../models/sync_settings.dart';
import '../services/connectivity_service.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});
  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  SyncSettings _settings = const SyncSettings();

  void _saveSettings(SyncSettings newSettings) {
    setState(() => _settings = newSettings);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки сохранены')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки синхронизации')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Когда синхронизировать',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          RadioGroup<SyncMode>(
            groupValue: _settings.mode,
            onChanged: (v) {
              if (v != null) _saveSettings(_settings.copyWith(mode: v));
            },
            child: Column(
              children: [
                const RadioListTile<SyncMode>(
                  title: Row(children: [
                    Icon(Icons.wifi),
                    SizedBox(width: 8),
                    Text('Только Wi-Fi')
                  ]),
                  subtitle: Text('Экономит мобильный трафик'),
                  value: SyncMode.wifiOnly,
                ),
                RadioListTile<SyncMode>(
                  title: Row(children: [
                    const Icon(Icons.signal_cellular_4_bar),
                    const SizedBox(width: 8),
                    Text(
                        'Wi-Fi и мобильная (до ${_settings.mobileDataPhotoLimitMb} МБ)')
                  ]),
                  value: SyncMode.wifiAndMobile,
                ),
                const RadioListTile<SyncMode>(
                  title: Row(children: [
                    Icon(Icons.touch_app),
                    SizedBox(width: 8),
                    Text('Вручную')
                  ]),
                  subtitle: Text('Ничего автоматически'),
                  value: SyncMode.manual,
                ),
              ],
            ),
          ),
          if (_settings.mode == SyncMode.wifiAndMobile) ...[
            const Divider(height: 32),
            const Text('Лимит размера фото'),
            Row(
              children: [
                const Text('Макс '),
                Expanded(
                  child: Slider(
                    value: _settings.mobileDataPhotoLimitMb.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '${_settings.mobileDataPhotoLimitMb} МБ',
                    onChanged: (v) => _saveSettings(
                        _settings.copyWith(mobileDataPhotoLimitMb: v.round())),
                  ),
                ),
                Text('${_settings.mobileDataPhotoLimitMb} МБ'),
              ],
            ),
          ],
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Синхронизировать на лимитном Wi-Fi'),
            subtitle: const Text('Гостиничный Wi-Fi, роуминг'),
            value: _settings.syncOnMeteredWifi,
            onChanged: (v) =>
                _saveSettings(_settings.copyWith(syncOnMeteredWifi: v)),
          ),
          const SizedBox(height: 32),
          FutureBuilder<ConnectionInfo>(
            future: ConnectivityService().checkConnection(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final c = snapshot.data!;
              return Card(
                child: ListTile(
                  leading: Icon(
                    c.isWifi
                        ? Icons.wifi
                        : c.isMobile
                            ? Icons.signal_cellular_4_bar
                            : Icons.wifi_off,
                    color: c.isConnected ? Colors.green : Colors.grey,
                  ),
                  title: Text(c.isWifi
                      ? 'Wi-Fi'
                      : c.isMobile
                          ? 'Мобильная сеть'
                          : 'Нет подключения'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
