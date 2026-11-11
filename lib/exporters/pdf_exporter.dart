import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import '../models/annotation.dart';

class PdfExporter {
  Future<String> export({
    required String drawingName,
    required List<Annotation> annotations,
    required String outputDirectory,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('Отчет по аннотациям',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Чертеж: $drawingName',
                style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Text('Всего точек: ${annotations.length}',
                style: const pw.TextStyle(fontSize: 14)),
          ],
        ),
      ),
    ));
    final chunks = _chunkList(annotations, 6);
    for (final chunk in chunks) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              color: PdfColors.grey300,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 30, child: pw.Text('№')),
                  pw.SizedBox(width: 80, child: pw.Text('Код')),
                  pw.Expanded(child: pw.Text('Описание')),
                  pw.SizedBox(width: 60, child: pw.Text('Фото')),
                ],
              ),
            ),
            ...chunk.map(_buildRow),
          ],
        ),
      ));
    }
    final fileName = '${_sanitize(drawingName)}_report.pdf';
    final filePath = p.join(outputDirectory, fileName);
    await File(filePath).writeAsBytes(await pdf.save());
    return filePath;
  }

  pw.Widget _buildRow(Annotation ann) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 30, child: pw.Text(ann.number.toString())),
          pw.SizedBox(width: 80, child: pw.Text(ann.code ?? '-')),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(ann.description ?? '-'),
                pw.Text(
                  'DXF: (${ann.dxfX.toStringAsFixed(2)}, ${ann.dxfY.toStringAsFixed(2)})',
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.SizedBox(
            width: 60,
            height: 60,
            child: ann.photos.isNotEmpty
                ? pw.Image(
                    pw.MemoryImage(
                        File(ann.photos.first.localFilePath).readAsBytesSync()),
                    fit: pw.BoxFit.cover)
                : pw.Container(
                    color: PdfColors.grey200,
                    child: pw.Center(child: pw.Text('Нет'))),
          ),
        ],
      ),
    );
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(
          i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  String _sanitize(String name) {
    return name.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
  }
}
