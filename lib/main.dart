// ==============================================================================
// CEMPPSA Field App - Main
// Punto de entrada de la aplicación
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

// Core
import 'core/config.dart';

// Repositorios
import 'repositories/catalogo_repository.dart';
import 'repositories/planilla_repository.dart';
import 'repositories/foto_repository.dart';

// API
import 'api/api_client.dart';

// Servicios
import 'services/sync_service.dart';
import 'services/foto_sync_service.dart';
import 'services/auth_service.dart';

// Pantallas
import 'package:cemppsa_field_app/ui/screens/home_screen.dart';
import 'package:cemppsa_field_app/ui/screens/manual_reading_screen.dart';
import 'package:cemppsa_field_app/ui/screens/cr10x_batch_screen.dart';
import 'package:cemppsa_field_app/ui/screens/planillas_hub_screen.dart';
import 'package:cemppsa_field_app/ui/screens/planilla_detail_screen.dart';
import 'package:cemppsa_field_app/ui/screens/export_csv_screen.dart';
import 'package:cemppsa_field_app/ui/screens/settings_screen.dart';
import 'package:cemppsa_field_app/ui/screens/fotos_screen.dart';
import 'package:cemppsa_field_app/ui/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar orientación
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configurar estilo de barra de estado
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F172A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Inicializar Hive
  await Hive.initFlutter();

  // Cargar configuraciones persistidas
  final settingsBox = await Hive.openBox(StorageConfig.settingsBox);
  
  final persistedBaseUrl =
      settingsBox.get(ApiConfig.settingsServerUrlKey)?.toString();
  if (persistedBaseUrl != null && persistedBaseUrl.trim().isNotEmpty) {
    ApiConfig.setBaseUrl(persistedBaseUrl);
  }

  final persistedTechName = settingsBox.get('technician_name')?.toString();
  if (persistedTechName != null && persistedTechName.trim().isNotEmpty) {
    AppConfig.technicianName = persistedTechName;
  }

  // Generar device ID si no existe
  AppConfig.deviceId ??= 'android_${const Uuid().v4().substring(0, 8)}';

  // Inicializar repositorios
  final catalogRepo = CatalogRepository(baseUrl: ApiConfig.baseUrl);
  await catalogRepo.init();

  final planillaRepo = PlanillaRepository();
  await planillaRepo.init();

  final fotoRepo = FotoRepository();
  await fotoRepo.init();

  // Inicializar servicios
  final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);
  final authService = AuthService(apiClient: apiClient);
  await authService.init();

  final syncService = SyncService(apiClient: apiClient);
  final fotoSyncService = FotoSyncService(repository: fotoRepo);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalogRepo),
        ChangeNotifierProvider.value(value: planillaRepo),
        ChangeNotifierProvider.value(value: fotoRepo),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: syncService),
        ChangeNotifierProvider.value(value: fotoSyncService),
      ],
      child: const CEMPPSAFieldApp(),
    ),
  );
}

class _AuthGateScreen extends StatelessWidget {
  const _AuthGateScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (_, auth, __) {
        if (!auth.isInitialized) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}

class CEMPPSAFieldApp extends StatelessWidget {
  const CEMPPSAFieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const _AuthGateScreen(),
      routes: {
        // Flujos de carga de datos
        '/manual-reading': (ctx) => const ManualReadingScreen(),
        '/cr10x-batch': (ctx) => const CR10XBatchScreen(),
        '/fotos': (ctx) => const FotosScreen(),

        // Gestión de planillas
        '/planillas': (ctx) => const PlanillasHubScreen(),
        '/planilla-detail': (ctx) => const PlanillaDetailScreen(),

        // Utilidades
        '/export': (ctx) => const ExportCsvScreen(),
        '/settings': (ctx) => const SettingsScreen(),
        '/login': (ctx) => const LoginScreen(),

        // Atajos para tabs de PlanillasHub
        '/drafts': (ctx) => const PlanillasHubScreen(),
        '/pending': (ctx) => const PlanillasHubScreen(),
        '/sent': (ctx) => const PlanillasHubScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              title: const Text('No encontrado'),
              backgroundColor: const Color(0xFF1E293B),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'Pantalla no encontrada',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.name ?? 'ruta desconocida',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(ctx, '/'),
                    child: const Text('Volver al inicio'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      primaryColor: const Color(0xFF3B82F6),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF22C55E),
        surface: Color(0xFF1E293B),
        error: Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Color(0xFF334155)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF3B82F6),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: Colors.grey[600]),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: Color(0xFF3B82F6),
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xFF64748B),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF3B82F6);
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: Color(0xFF64748B)),
      ),
    );
  }
}
