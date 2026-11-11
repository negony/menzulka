import 'audio_note.dart';
import 'photo.dart';

class Annotation {
  final String id;
  final String drawingId;
  final int number;

  /// Координаты точки в системе чертежа — совпадает с DXF (единая система).
  final double dxfX;
  final double dxfY;

  /// Устарели: единая система координат совпадает с DXF, новые точки их не
  /// заполняют; оставлены для совместимости со старыми записями.
  final double? geoX;
  final double? geoY;

  /// Высота (отметка) точки.
  final double? geoZ;
  final String? code;
  final String? description;
  final List<Photo> photos;
  final List<AudioNote> audioNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Annotation({
    required this.id,
    required this.drawingId,
    required this.number,
    required this.dxfX,
    required this.dxfY,
    this.geoX,
    this.geoY,
    this.geoZ,
    this.code,
    this.description,
    this.photos = const [],
    this.audioNotes = const [],
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Annotation copyWith({
    String? id,
    String? drawingId,
    int? number,
    double? dxfX,
    double? dxfY,
    double? geoX,
    double? geoY,
    double? geoZ,
    String? code,
    String? description,
    List<Photo>? photos,
    List<AudioNote>? audioNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Annotation(
      id: id ?? this.id,
      drawingId: drawingId ?? this.drawingId,
      number: number ?? this.number,
      dxfX: dxfX ?? this.dxfX,
      dxfY: dxfY ?? this.dxfY,
      geoX: geoX ?? this.geoX,
      geoY: geoY ?? this.geoY,
      geoZ: geoZ ?? this.geoZ,
      code: code ?? this.code,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      audioNotes: audioNotes ?? this.audioNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
