import 'package:flutter/material.dart';
import '../models/annotation.dart';
import '../utils/marker_clusterer.dart';

class ClusteredMarkerPainter extends CustomPainter {
  final List<MarkerCluster> clusters;
  ClusteredMarkerPainter({required this.clusters});

  @override
  void paint(Canvas canvas, Size size) {
    for (final cluster in clusters) {
      final center = Offset(cluster.centerX, cluster.centerY);
      if (center.dx < -50 ||
          center.dy < -50 ||
          center.dx > size.width + 50 ||
          center.dy > size.height + 50) {
        continue;
      }
      if (cluster.isSingle) {
        _drawSingleMarker(canvas, center, cluster.annotations.first);
      } else {
        _drawClusterBubble(canvas, center, cluster.count);
      }
    }
  }

  void _drawSingleMarker(Canvas canvas, Offset center, Annotation ann) {
    final fill = Paint()..color = const Color(0xFFD32F2F);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 12, fill);
    canvas.drawCircle(center, 12, border);
    final tp = TextPainter(
      text: TextSpan(
        text: '${ann.number}',
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  void _drawClusterBubble(Canvas canvas, Offset center, int count) {
    final fill = Paint()..color = const Color(0xFF1976D2);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final radius = 16.0 + (count > 10 ? 4.0 : 0.0);
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, border);
    final tp = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant ClusteredMarkerPainter oldDelegate) {
    return oldDelegate.clusters != clusters;
  }
}
