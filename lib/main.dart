import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/app_theme.dart';
import 'services/offline_storage.dart';
import 'services/network_manager.dart';
import 'repositories/planillas_repository.dart';
import 'services/sync_service.dart';
import 'ui/screens/home_screen.dart';
import 'repositories/catalog_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Inicializamos Hive UNA sola vez para toda la app
  await Hive.initFlutter();

  // ---------- Servicios base ----------
  final offline = OfflineStorage();
  await offline.init();

  final net = NetworkManager();
  await net.start();

  // ---------- Repo principal (con persistencia local) ----------
  final repo = PlanillasRepository(net: net, offline: offline);
  await repo.init(); // carga planillas guardadas en Hive

  // ---------- Servicio de sincronización ----------
  final sync = SyncService(net: net, offline: offline, repo: repo);
  sync.start();

  runApp(
    MultiProvider(
      providers: [
        Provider<OfflineStorage>.value(value: offline),
        ChangeNotifierProvider<NetworkManager>.value(value: net),
        ChangeNotifierProvider<CatalogRepository>(create: (_) => CatalogRepository()),
        ChangeNotifierProvider<PlanillasRepository>.value(value: repo),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    ),
  );
}
