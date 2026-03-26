// ==============================================================================
// CEMPPSA Field App - Planilla Repository
// Gestión local de planillas (borradores, pendientes, historial)
// ==============================================================================

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/models/planilla.dart';
import '../utils/json_maps.dart';

/// Repositorio de planillas con persistencia local (Hive)
class PlanillaRepository extends ChangeNotifier {
  static const String _boxName = 'planillas_v2';

  late Box _box;
  bool _initialized = false;

  /// Planillas en memoria indexadas por UUID
  final Map<String, Planilla> _planillas = {};

  bool get isInitialized => _initialized;

  // =========================================================================
  // Inicialización
  // =========================================================================

  Future<void> init() async {
    if (_initialized) return;

    _box = await Hive.openBox(_boxName);
    await _loadFromCache();

    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadFromCache() async {
    for (final value in _box.values) {
      if (value is Map) {
        try {
          final json = convertToStringDynamicMap(value);
          final planilla = Planilla.fromJson(json);
          _planillas[planilla.batchUuid] = planilla;
        } catch (e) {
          debugPrint('Error cargando planilla del cache: $e');
        }
      }
    }
    debugPrint('Planillas cargadas del cache: ${_planillas.length}');
  }

  // =========================================================================
  // CRUD
  // =========================================================================

  /// Guarda una planilla (nueva o existente)
  Future<void> save(Planilla planilla) async {
    _planillas[planilla.batchUuid] = planilla;
    await _box.put(planilla.batchUuid, planilla.toJson());
    notifyListeners();
  }

  Future<int> recoverInterruptedSends() async {
    final interrupted = _planillas.values
        .where((planilla) => planilla.estado == PlanillaEstado.enviando)
        .toList();

    if (interrupted.isEmpty) {
      return 0;
    }

    for (final planilla in interrupted) {
      planilla.recoverInterruptedSend();
      await _box.put(planilla.batchUuid, planilla.toJson());
    }

    debugPrint(
      'PlanillaRepository: recuperadas ${interrupted.length} planillas '
      'que quedaron en ENVIANDO tras un cierre abrupto.',
    );
    notifyListeners();
    return interrupted.length;
  }

  /// Obtiene una planilla por UUID
  Planilla? get(String batchUuid) => _planillas[batchUuid];

  /// Elimina una planilla
  Future<void> delete(String batchUuid) async {
    _planillas.remove(batchUuid);
    await _box.delete(batchUuid);
    notifyListeners();
  }

  /// Elimina todas las planillas
  Future<void> clear() async {
    _planillas.clear();
    await _box.clear();
    notifyListeners();
  }

  // =========================================================================
  // Consultas
  // =========================================================================

  /// Todas las planillas
  List<Planilla> all() => _planillas.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Total de planillas
  int get count => _planillas.length;

  /// Planillas por estado
  List<Planilla> byEstado(PlanillaEstado estado) =>
      _planillas.values.where((p) => p.estado == estado).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Borradores (en edición)
  List<Planilla> get borradores => byEstado(PlanillaEstado.borrador);

  /// Pendientes de envío
  List<Planilla> get pendientes => _planillas.values
      .where((p) =>
          p.estado == PlanillaEstado.pendiente ||
          p.estado == PlanillaEstado.rechazada ||
          p.estado == PlanillaEstado.error)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Enviadas exitosamente
  List<Planilla> get enviadas => byEstado(PlanillaEstado.enviada);

  /// Por tipo de planilla
  List<Planilla> byTipo(TipoPlanilla tipo) =>
      _planillas.values.where((p) => p.tipo == tipo).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // =========================================================================
  // Estadísticas
  // =========================================================================

  /// Resumen de cantidades por estado
  Map<PlanillaEstado, int> get resumenPorEstado {
    final resumen = <PlanillaEstado, int>{};
    for (final estado in PlanillaEstado.values) {
      resumen[estado] = byEstado(estado).length;
    }
    return resumen;
  }

  /// Total de lecturas pendientes
  int get totalLecturasPendientes =>
      pendientes.fold(0, (sum, p) => sum + p.totalLecturas);

  // =========================================================================
  // Operaciones de workflow
  // =========================================================================

  /// Marca una planilla como lista para enviar
  Future<void> marcarPendiente(String batchUuid) async {
    final planilla = _planillas[batchUuid];
    if (planilla != null) {
      planilla.marcarPendiente();
      await save(planilla);
    }
  }

  /// Marca una planilla como enviada
  Future<void> marcarEnviada(String batchUuid) async {
    final planilla = _planillas[batchUuid];
    if (planilla != null) {
      planilla.marcarEnviada();
      await save(planilla);
    }
  }

  /// Marca una planilla con error
  Future<void> marcarError(String batchUuid, String mensaje) async {
    final planilla = _planillas[batchUuid];
    if (planilla != null) {
      planilla.marcarError(mensaje);
      await save(planilla);
    }
  }

  // =========================================================================
  // Limpieza
  // =========================================================================

  /// Elimina planillas enviadas con más de N días
  Future<int> limpiarEnviadas({int diasAntiguedad = 30}) async {
    final limite = DateTime.now().subtract(Duration(days: diasAntiguedad));
    final aEliminar = enviadas
        .where((p) => p.createdAt.isBefore(limite))
        .map((p) => p.batchUuid)
        .toList();

    for (final uuid in aEliminar) {
      await delete(uuid);
    }

    return aEliminar.length;
  }
}
