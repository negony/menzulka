class Photo {
  final String id;
  final String annotationId;
  final String localFilePath;
  final String? thumbnailPath;
  final DateTime createdAt;
  final bool isUploaded;
  final String? fileUrl;

  Photo({
    required this.id,
    required this.annotationId,
    required this.localFilePath,
    this.thumbnailPath,
    required this.createdAt,
    this.isUploaded = false,
    this.fileUrl,
  });
}
