import '../models/photo.dart';

class PhotoSyncStrategy {
  Future<List<Photo>> getPendingPhotos() async => [];
  Future<void> uploadPhoto(Photo photo) async {}
  Future<String> computeSha256(String filePath) async => '';
}
