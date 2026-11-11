import 'dart:io';

/// Тестовый DXF для проверки объектных привязок:
/// LINE, LWPOLYLINE-прямоугольник, POLYLINE, ARC, CIRCLE, ELLIPSE,
/// POINT, полилиния с bulge и INSERT блока.
///
/// Запуск: `dart run tool/generate_snap_test_dxf.dart`
/// Результат: `build/test_data/snap_test.dxf`
void main() {
  final b = StringBuffer();

  void pair(Object code, Object value) {
    b.writeln(code);
    b.writeln(value);
  }

  void line(double x1, double y1, double x2, double y2) {
    pair(0, 'LINE');
    pair(8, 'SNAP');
    pair(10, x1);
    pair(20, y1);
    pair(30, 0);
    pair(11, x2);
    pair(21, y2);
    pair(31, 0);
  }

  void text(double x, double y, String s) {
    pair(0, 'TEXT');
    pair(8, 'SNAP');
    pair(10, x);
    pair(20, y);
    pair(30, 0);
    pair(40, 8);
    pair(1, s);
  }

  // --- HEADER ---
  pair(0, 'SECTION');
  pair(2, 'HEADER');
  pair(9, r'$ACADVER');
  pair(1, 'AC1032');
  pair(0, 'ENDSEC');

  // --- TABLES ---
  pair(0, 'SECTION');
  pair(2, 'TABLES');
  pair(0, 'TABLE');
  pair(2, 'LAYER');
  pair(70, 1);
  pair(0, 'LAYER');
  pair(2, 'SNAP');
  pair(70, 0);
  pair(62, 7);
  pair(6, 'CONTINUOUS');
  pair(0, 'ENDTAB');
  pair(0, 'ENDSEC');

  // --- BLOCKS: символ с крестом и окружностью ---
  pair(0, 'SECTION');
  pair(2, 'BLOCKS');
  pair(0, 'BLOCK');
  pair(2, 'SYMBOL');
  pair(70, 0);
  pair(10, 0);
  pair(20, 0);
  pair(30, 0);
  line(-20, 0, 20, 0);
  line(0, -20, 0, 20);
  pair(0, 'CIRCLE');
  pair(8, 'SNAP');
  pair(10, 0);
  pair(20, 0);
  pair(40, 12);
  pair(0, 'ENDBLK');
  pair(0, 'ENDSEC');

  // --- ENTITIES ---
  pair(0, 'SECTION');
  pair(2, 'ENTITIES');

  // LINE: вершины (100,100) и (300,100).
  line(100, 100, 300, 100);
  text(170, 82, 'LINE');

  // RECT: замкнутая LWPOLYLINE, углы (400,100)…(600,250).
  pair(0, 'LWPOLYLINE');
  pair(8, 'SNAP');
  pair(90, 4);
  pair(70, 1);
  pair(10, 400);
  pair(20, 100);
  pair(10, 600);
  pair(20, 100);
  pair(10, 600);
  pair(20, 250);
  pair(10, 400);
  pair(20, 250);
  text(480, 82, 'RECT');

  // POLYLINE (старая, через VERTEX/SEQEND).
  pair(0, 'POLYLINE');
  pair(8, 'SNAP');
  pair(66, 1);
  pair(70, 0);
  for (final p in [(700.0, 100.0), (800.0, 200.0), (900.0, 100.0)]) {
    pair(0, 'VERTEX');
    pair(8, 'SNAP');
    pair(10, p.$1);
    pair(20, p.$2);
  }
  pair(0, 'SEQEND');
  pair(8, 'SNAP');
  text(770, 82, 'POLYLINE');

  // ARC: центр (150,400), r=80, 0°…90°.
  pair(0, 'ARC');
  pair(8, 'SNAP');
  pair(10, 150);
  pair(20, 400);
  pair(40, 80);
  pair(50, 0);
  pair(51, 90);
  text(250, 380, 'ARC');

  // CIRCLE: центр (400,400), r=60.
  pair(0, 'CIRCLE');
  pair(8, 'SNAP');
  pair(10, 400);
  pair(20, 400);
  pair(40, 60);
  text(360, 320, 'CIRCLE');

  // ELLIPSE: центр (700,400), большая полуось (100,0), ratio 0.5.
  pair(0, 'ELLIPSE');
  pair(8, 'SNAP');
  pair(10, 700);
  pair(20, 400);
  pair(11, 100);
  pair(21, 0);
  pair(40, 0.5);
  pair(41, 0);
  pair(42, 6.283185307179586);
  text(650, 320, 'ELLIPSE');

  // POINT: узел (150,700).
  pair(0, 'POINT');
  pair(8, 'SNAP');
  pair(10, 150);
  pair(20, 700);
  pair(30, 0);
  text(180, 700, 'POINT');

  // BULGE: дуга-полилиния (300,700) → (500,700).
  pair(0, 'LWPOLYLINE');
  pair(8, 'SNAP');
  pair(90, 2);
  pair(70, 0);
  pair(10, 300);
  pair(20, 700);
  pair(42, 1);
  pair(10, 500);
  pair(20, 700);
  text(350, 670, 'BULGE');

  // INSERT блока SYMBOL: точка вставки (700,700).
  pair(0, 'INSERT');
  pair(8, 'SNAP');
  pair(2, 'SYMBOL');
  pair(10, 700);
  pair(20, 700);
  pair(41, 1);
  pair(42, 1);
  pair(50, 0);
  text(650, 760, 'BLOCK');

  pair(0, 'ENDSEC');
  pair(0, 'EOF');

  final dir = Directory('build/test_data');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final file = File('${dir.path}/snap_test.dxf');
  file.writeAsStringSync(b.toString());
  stdout.writeln('written: ${file.path}');
}
