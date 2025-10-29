import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'repositories/planillas_repository.dart';
import 'ui/screens/home_screen.dart';
import 'services/connectivity_status.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CemppsaApp());
}

class CemppsaApp extends StatelessWidget {
  const CemppsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlanillasRepository()),
        ChangeNotifierProvider(create: (_) => ConnectivityStatus()..init()),
      ],
      child: MaterialApp(
        title: 'CEMPPSA Field',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
