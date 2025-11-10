import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/offline_storage.dart';
import 'services/network_manager.dart';
import 'repositories/planillas_repository.dart';
import 'services/sync_service.dart';
import 'ui/screens/home_screen.dart';
import 'repositories/catalog_repository.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final offline = OfflineStorage();
  await offline.init();

  final net = NetworkManager();
  await net.start();

  // Construí primero el repo para poder pasárselo al SyncService
  final repo = PlanillasRepository(net: net, offline: offline);

  final sync = SyncService(net: net, offline: offline, repo: repo);
  sync.start();

  runApp(
  MultiProvider(
    providers: [
      Provider<OfflineStorage>.value(value: offline),
      ChangeNotifierProvider<NetworkManager>.value(value: net),

      /// ⬇⬇⬇ AÑADIR ESTO
      ChangeNotifierProvider<CatalogRepository>(
        create: (_) => CatalogRepository(),
      ),
      /// ⬆⬆⬆

      ChangeNotifierProvider<PlanillasRepository>(
        create: (_) => PlanillasRepository(net: net, offline: offline),
      ),
    ],
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    ),
  ),
);
}
