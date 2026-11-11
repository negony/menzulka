import 'package:flutter/material.dart';
import 'screens/drawing_screen.dart';
import 'services/app_prefs.dart';
import 'services/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService.instance;
  await db.database;
  await AppPrefs.instance.load();
  runApp(const MenzulkaApp());
}

class MenzulkaApp extends StatelessWidget {
  const MenzulkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мензулка',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DrawingScreen(), // Убрали drawingId
    );
  }
}
