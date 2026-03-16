// ==============================================================================
// CEMPPSA Field App - Main
// Punto de entrada de la aplicación
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

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
import 'utils/server_discovery.dart';

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
import 'package:cemppsa_field_app/ui/screens/offline_unlock_screen.dart';

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

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
    if (ApiConfig.shouldReplacePersistedBaseUrl(persistedBaseUrl)) {
      ApiConfig.setBaseUrl(ApiConfig.defaultBaseUrl, markAsCustom: false);
      await settingsBox.put(
        ApiConfig.settingsServerUrlKey,
        ApiConfig.defaultBaseUrl,
      );
    } else {
      ApiConfig.setBaseUrl(persistedBaseUrl, markAsCustom: true);
    }
  } else {
    ApiConfig.setBaseUrl(ApiConfig.defaultBaseUrl, markAsCustom: false);
  }

  final persistedTechName = settingsBox.get('technician_name')?.toString();
  if (persistedTechName != null && persistedTechName.trim().isNotEmpty) {
    AppConfig.technicianName = persistedTechName;
  }

  // Generar device ID si no existe
  AppConfig.deviceId ??= 'android_${const Uuid().v4().substring(0, 8)}';

  // Inicializar repositorios
  final catalogRepo = CatalogRepository(
    baseUrl: ApiConfig.hasConfiguredBaseUrl ? ApiConfig.baseUrl : null,
  );
  await catalogRepo.init();
  if (ApiConfig.hasConfiguredBaseUrl && catalogRepo.needsSync) {
    // Primera lectura de catálogo+rango por instrumento (best effort).
    unawaited(catalogRepo.syncFromBackend());
  }

  final planillaRepo = PlanillaRepository();
  await planillaRepo.init();

  final fotoRepo = FotoRepository();
  await fotoRepo.init();

  // Inicializar servicios
  final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);
  final authService = AuthService(apiClient: apiClient);
  await authService.init();
  ApiConfig.refreshAuthToken = authService.refreshSession;
  ApiConfig.handleSessionExpired = () async {
    await authService.handleSessionExpired();
    _appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
    );
  };

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
        if (!auth.hasStoredSession) {
          return const LoginScreen();
        }
        if (auth.requiresLocalUnlock) {
          return const OfflineUnlockScreen();
        }
        return const HomeScreen();
      },
    );
  }
}

class CEMPPSAFieldApp extends StatefulWidget {
  const CEMPPSAFieldApp({super.key});

  @override
  State<CEMPPSAFieldApp> createState() => _CEMPPSAFieldAppState();
}

class _CEMPPSAFieldAppState extends State<CEMPPSAFieldApp>
    with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _connectivitySub;
  bool _isResolvingServer = false;
  DateTime? _lastServerResolveAttempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      if (!_hasAnyConnection(result)) return;
      unawaited(_ensureReachableServer(reason: 'connectivity_changed'));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureReachableServer(reason: 'startup', force: true));
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    final auth = context.read<AuthService>();

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      auth.lockLocallyIfNeeded();
      return;
    }

    if (state == AppLifecycleState.resumed && auth.requiresLocalUnlock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/',
          (_) => false,
        );
      });
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_ensureReachableServer(reason: 'app_resumed'));
    }
  }

  bool _hasAnyConnection(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.any((value) => value != ConnectivityResult.none);
    }
    return false;
  }

  Future<void> _ensureReachableServer({
    required String reason,
    bool force = false,
  }) async {
    if (!mounted || _isResolvingServer) return;

    final lastAttempt = _lastServerResolveAttempt;
    if (!force &&
        lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < const Duration(seconds: 15)) {
      return;
    }

    final connectivity = await _connectivity.checkConnectivity();
    if (!_hasAnyConnection(connectivity)) {
      return;
    }

    _isResolvingServer = true;
    _lastServerResolveAttempt = DateTime.now();

    try {
      if (!mounted) return;
      final syncService = context.read<SyncService>();
      final currentIsReachable = await syncService.checkConnection();
      if (currentIsReachable) {
        return;
      }

      final discoveredUrl = await ServerDiscovery.findServer();
      final normalized = discoveredUrl == null
          ? null
          : ApiConfig.normalizeBaseUrl(discoveredUrl);
      if (normalized == null) {
        debugPrint(
          'AutoServerResolver: sin hallazgos para reason=$reason baseUrl=${ApiConfig.baseUrl}',
        );
        return;
      }

      if (normalized == ApiConfig.baseUrl && ApiConfig.hasCustomBaseUrl) {
        debugPrint(
          'AutoServerResolver: el servidor detectado coincide con la URL actual ($normalized)',
        );
        return;
      }

      ApiConfig.setBaseUrl(normalized, markAsCustom: true);
      final settingsBox = await Hive.openBox(StorageConfig.settingsBox);
      await settingsBox.put(ApiConfig.settingsServerUrlKey, normalized);

      if (!mounted) return;

      context.read<AuthService>().updateApiBaseUrl(normalized);
      syncService.updateApiBaseUrl(normalized);
      context.read<CatalogRepository>().setBaseUrl(normalized);

      debugPrint(
        'AutoServerResolver: servidor actualizado automaticamente a $normalized (reason=$reason)',
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('AutoServerResolver: error resolviendo servidor: $e');
    } finally {
      _isResolvingServer = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: _appNavigatorKey,
      theme: _buildTheme(),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const _AuthGateScreen(),
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
