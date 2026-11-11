import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/annotation.dart';
import '../models/dxf_models.dart';

class MarkerCluster {
  final List<Annotation> annotations;
  final double centerX;
  final double centerY;
  MarkerCluster(
      {required this.annotations,
      required this.centerX,
      required this.centerY});
  bool get isSingle => annotations.length == 1;
  int get count => annotations.length;
}

class MarkerClusterer {
  List<MarkerCluster> clusterize({
    required List<Annotation> annotations,
    required DxfDocument document,
    required Matrix4 matrix,
    required double minDistancePx,
  }) {
    if (annotations.isEmpty) return [];
    final screenPositions = <String, Offset>{};
    for (final ann in annotations) {
      // Абсолютные координаты аннотации -> локальные координаты вьюера -> экран.
      final local = Offset(ann.dxfX - document.minX, document.maxY - ann.dxfY);
      final screen = _toScreen(local, matrix);
      screenPositions[ann.id] = screen;
    }
    final cellSize = minDistancePx;
    final grid = <String, List<Annotation>>{};
    for (final ann in annotations) {
      final pos = screenPositions[ann.id]!;
      final cellKey =
          '${(pos.dx / cellSize).floor()}_${(pos.dy / cellSize).floor()}';
      grid.putIfAbsent(cellKey, () => []).add(ann);
    }
    final clusters = <MarkerCluster>[];
    for (final entry in grid.entries) {
      final anns = entry.value;
      if (anns.length == 1) {
        final pos = screenPositions[anns.first.id]!;
        clusters.add(
            MarkerCluster(annotations: anns, centerX: pos.dx, centerY: pos.dy));
      } else {
        double sumX = 0, sumY = 0;
        for (final ann in anns) {
          final pos = screenPositions[ann.id]!;
          sumX += pos.dx;
          sumY += pos.dy;
        }
        clusters.add(MarkerCluster(
            annotations: anns,
            centerX: sumX / anns.length,
            centerY: sumY / anns.length));
      }
    }
    return clusters;
  }

  Offset _toScreen(Offset local, Matrix4 matrix) {
    final v = matrix.transform3(Vector3(local.dx, local.dy, 0));
    return Offset(v.x, v.y);
  }
}
