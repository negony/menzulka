import 'package:flutter/material.dart';
import '../screens/drawing_screen.dart';

class WorkspaceDock extends StatelessWidget {
  final DrawingMode currentMode;
  final Function(DrawingMode) onModeChanged;
  const WorkspaceDock(
      {super.key, required this.currentMode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          _buildButton(Icons.pan_tool, 'Обзор', DrawingMode.overview),
          _buildButton(
              Icons.my_location, 'Координаты', DrawingMode.coordinates),
          _buildButton(Icons.add_location, 'Точка', DrawingMode.annotation),
          _buildButton(Icons.straighten, 'Измерить', DrawingMode.measurement),
          _buildButton(Icons.edit, 'Рисование', DrawingMode.drawing),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, String label, DrawingMode mode) {
    final selected = currentMode == mode;
    // Явный цвет: унаследованный цвет темы (Material 3) на настольных сборках
    // получался серым — подписи в нижней панели плохо читались.
    final color = selected ? Colors.blue[700]! : Colors.black87;
    return Expanded(
      child: InkWell(
        onTap: () => onModeChanged(mode),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
