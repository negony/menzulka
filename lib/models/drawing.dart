class Drawing {
  final String id;
  final String projectId;
  final String name;
  final String localFilePath;
  final String? units;
  final int nextAnnotationNumber;
  final DateTime createdAt;

  Drawing({
    required this.id,
    required this.projectId,
    required this.name,
    required this.localFilePath,
    this.units = 'm',
    this.nextAnnotationNumber = 1,
    required this.createdAt,
  });
}
