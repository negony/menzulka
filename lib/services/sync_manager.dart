import 'dart:io';
import '../models/sync_settings.dart';
import 'connectivity_service.dart';

class SyncPermission {
  final bool canSyncMetadata;
  final bool canSyncPhotos;
  final String? reason;
  const SyncPermission({
    required this.canSyncMetadata,
    required this.canSyncPhotos,
    this.reason,
  });
}

class SyncManager {
  final ConnectivityService _connectivity;
  final SyncSettings settings;
  SyncManager(
      {required ConnectivityService connectivity, required this.settings})
      : _connectivity = connectivity;

  Future<SyncPermission> checkSyncPermission() async {
    final connection = await _connectivity.checkConnection();
    if (settings.mode == SyncMode.manual) {
      return const SyncPermission(
          canSyncMetadata: false, canSyncPhotos: false, reason: 'Ручной режим');
    }
    if (!connection.isConnected) {
      return const SyncPermission(
          canSyncMetadata: false,
          canSyncPhotos: false,
          reason: 'Нет подключения');
    }
    if (connection.isWifi) {
      if (connection.isMetered && !settings.syncOnMeteredWifi) {
        return const SyncPermission(
            canSyncMetadata: true,
            canSyncPhotos: false,
            reason: 'Лимитный Wi-Fi');
      }
      return const SyncPermission(canSyncMetadata: true, canSyncPhotos: true);
    }
    if (connection.isMobile) {
      if (settings.mode == SyncMode.wifiOnly) {
        return const SyncPermission(
            canSyncMetadata: false,
            canSyncPhotos: false,
            reason: 'Мобильная сеть отключена');
      }
      return const SyncPermission(canSyncMetadata: true, canSyncPhotos: true);
    }
    return const SyncPermission(canSyncMetadata: false, canSyncPhotos: false);
  }

  Future<bool> canUploadPhoto(String filePath) async {
    final permission = await checkSyncPermission();
    if (!permission.canSyncPhotos) return false;
    final connection = await _connectivity.checkConnection();
    if (connection.isMobile && settings.mode == SyncMode.wifiAndMobile) {
      final fileSize = await File(filePath).length();
      final fileSizeMb = fileSize / (1024 * 1024);
      return fileSizeMb <= settings.mobileDataPhotoLimitMb;
    }
    return true;
  }
}
