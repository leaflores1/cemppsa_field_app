import 'package:flutter/material.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CemppsaApp());
}

class CemppsaApp extends StatelessWidget {
  const CemppsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CEMPPSA Field',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomeScreen(),
    );
  }
}
