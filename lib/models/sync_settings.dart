enum SyncMode { wifiOnly, wifiAndMobile, manual }

class SyncSettings {
  final SyncMode mode;
  final int mobileDataPhotoLimitMb;
  final bool syncOnMeteredWifi;
  const SyncSettings({
    this.mode = SyncMode.wifiOnly,
    this.mobileDataPhotoLimitMb = 5,
    this.syncOnMeteredWifi = false,
  });
  SyncSettings copyWith(
      {SyncMode? mode, int? mobileDataPhotoLimitMb, bool? syncOnMeteredWifi}) {
    return SyncSettings(
      mode: mode ?? this.mode,
      mobileDataPhotoLimitMb:
          mobileDataPhotoLimitMb ?? this.mobileDataPhotoLimitMb,
      syncOnMeteredWifi: syncOnMeteredWifi ?? this.syncOnMeteredWifi,
    );
  }
}
