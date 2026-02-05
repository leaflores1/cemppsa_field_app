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
import 'core/storage/secure_storage_service.dart';

// Repositorios
import 'repositories/catalogo_repository.dart';
import 'repositories/planilla_repository.dart';

// API
import 'api/api_client.dart';

// Servicios
import 'services/sync_service.dart';
import 'services/auth_service.dart';

// Pantallas
import 'ui/screens/home_screen.dart';
import 'ui/screens/manual_reading_screen.dart';
import 'ui/screens/cr10x_batch_screen.dart';
import 'ui/screens/planillas_hub_screen.dart';
import 'ui/screens/planilla_detail_screen.dart';
import 'ui/screens/export_csv_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/auth/register_screen.dart';
import 'ui/widgets/role_gate.dart';

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

  // Generar device ID si no existe
  AppConfig.deviceId ??= 'android_${const Uuid().v4().substring(0, 8)}';

  // Secure Storage
  final secureStorage = SecureStorageService();

  // Inicializar ApiClient & AuthService
  final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl, storage: secureStorage);
  final authService = AuthService(apiClient: apiClient, storage: secureStorage);

  // Inicializar repositorios
  final catalogRepo = CatalogRepository(baseUrl: ApiConfig.baseUrl);
  await catalogRepo.init();

  final planillaRepo = PlanillaRepository();
  await planillaRepo.init();

  // Inicializar servicios
  final syncService = SyncService(apiClient: apiClient);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: catalogRepo),
        ChangeNotifierProvider.value(value: planillaRepo),
        ChangeNotifierProvider.value(value: syncService),
      ],
      child: const CEMPPSAFieldApp(),
    ),
  );
}

class CEMPPSAFieldApp extends StatefulWidget {
  const CEMPPSAFieldApp({super.key});

  @override
  State<CEMPPSAFieldApp> createState() => _CEMPPSAFieldAppState();
}

class _CEMPPSAFieldAppState extends State<CEMPPSAFieldApp> {
  @override
  void initState() {
    super.initState();
    // Verificar sesión al inicio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AuthWrapper(),
      routes: {
        // Auth
        '/login': (ctx) => const LoginScreen(),
        '/register': (ctx) => const RegisterScreen(),

        // Home explicito
        '/home': (ctx) => const HomeScreen(),

        // Flujos de carga de datos (protegidos)
        '/manual-reading': (ctx) => const RoleGate(child: ManualReadingScreen()),
        '/cr10x-batch': (ctx) => const RoleGate(child: CR10XBatchScreen()),

        // Gestión de planillas
        '/planillas': (ctx) => const RoleGate(child: PlanillasHubScreen()),
        '/planilla-detail': (ctx) => const RoleGate(child: PlanillaDetailScreen()),

        // Utilidades
        '/export': (ctx) => const RoleGate(child: ExportCsvScreen()),
        '/settings': (ctx) => const RoleGate(child: SettingsScreen()),

        // Atajos para tabs de PlanillasHub
        '/drafts': (ctx) => const RoleGate(child: PlanillasHubScreen()),
        '/pending': (ctx) => const RoleGate(child: PlanillasHubScreen()),
        '/sent': (ctx) => const RoleGate(child: PlanillasHubScreen()),
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(ctx, '/home'),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               CircularProgressIndicator(color: Color(0xFF3B82F6)),
               SizedBox(height: 16),
               Text('Iniciando sesión segura...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }
    return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}
