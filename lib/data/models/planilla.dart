// ==============================================================================
// CEMPPSA Field App - Modelo Planilla (Batch)
// Alineado con: backend SyncBatchRequest
// ==============================================================================

import 'package:uuid/uuid.dart';
import 'lectura.dart';

/// Estado de la planilla en el ciclo de vida local
enum PlanillaEstado {
  /// Borrador en edición
  borrador,

  /// Lista para enviar (guardada localmente)
  pendiente,

  /// En proceso de envío
  enviando,

  /// Enviada exitosamente al servidor
  enviada,

  /// Error en el envío (reintentable)
  error,
}

/// Tipo de planilla (para clasificación en UI y backend)
/// Corresponde al campo `planilla_nombre` o `tipo_planilla`
enum TipoPlanilla {
  /// Piezómetros Casagrande (lectura manual semanal)
  casagrande('CASAGRANDE', 'Piezómetros Casagrande'),

  /// Freatímetros (lectura manual semanal)
  freatimetros('FREATIMETROS', 'Freatímetros'),

  /// Aforadores (lectura manual semanal)
  aforadores('AFORADORES', 'Aforadores'),

  /// CR10X Piezómetros (carga contingencia)
  cr10xPiezometros('CR10X_PIEZ', 'CR10X Piezómetros'),

  /// CR10X Asentímetros (carga contingencia)
  cr10xAsentimetros('CR10X_ASEN', 'CR10X Asentímetros'),

  /// CR10X Triaxiales (carga contingencia)
  cr10xTriaxiales('CR10X_TRIAX', 'CR10X Triaxiales'),

  /// CR10X Uniaxiales (carga contingencia)
  cr10xUniaxiales('CR10X_UNIAX', 'CR10X Uniaxiales'),

  /// CR10X Termómetros (carga contingencia)
  cr10xTermometros('CR10X_TERMO', 'CR10X Termómetros'),

  /// CR10X Clinómetros (carga contingencia)
  cr10xClinometros('CR10X_CLINO', 'CR10X Clinómetros'),

  /// CR10X Barómetro (carga contingencia)
  cr10xBarometro('CR10X_BARO', 'CR10X Barómetro'),

  /// CR10X Celdas de Presión (carga contingencia)
  cr10xCeldasPresion('CR10X_CELDA', 'CR10X Celdas de Presión'),

  /// Sismos (lectura manual)
  sismos('SISMOS', 'Sismos'),

  /// Triaxiales (3 ejes X, Y, Z - lectura manual)
  triaxiales('TRIAXIALES', 'Triaxiales'),

  /// Planilla mixta o genérica
  general('GENERAL', 'General');

  final String codigo;
  final String displayName;

  const TipoPlanilla(this.codigo, this.displayName);

  static TipoPlanilla fromCodigo(String codigo) {
    return TipoPlanilla.values.firstWhere(
      (t) => t.codigo == codigo.toUpperCase(),
      orElse: () => TipoPlanilla.general,
    );
  }
}

/// Modelo de Planilla (Batch) para sincronización.
/// 
/// Mapea exactamente a `SyncBatchRequest` del backend:
/// ```json
/// {
///   "batch_uuid": "...",
///   "device_id": "...",
///   "technician_id": "...",
///   "created_at": "...",
///   "planilla_nombre": "CASAGRANDE",
///   "readings": [...]
/// }
/// ```
class Planilla {
  /// UUID único del lote (generado en cliente)
  final String batchUuid;

  /// Tipo de planilla
  final TipoPlanilla tipo;

  /// ID del dispositivo (para trazabilidad)
  final String deviceId;

  /// ID del técnico (usuario logueado)
  final String technicianId;

  /// Fecha de creación de la planilla
  final DateTime createdAt;

  /// Estado actual
  PlanillaEstado estado;

  /// Lista de lecturas del lote
  final List<Lectura> lecturas;

  /// Observaciones generales de la planilla
  String? observaciones;

  /// Mensaje de error si estado == error
  String? errorMessage;

  /// Fecha del último intento de envío
  DateTime? lastSyncAttempt;

  /// Contador de reintentos
  int syncRetries;

  Planilla({
    String? batchUuid,
    required this.tipo,
    required this.deviceId,
    required this.technicianId,
    DateTime? createdAt,
    this.estado = PlanillaEstado.borrador,
    List<Lectura>? lecturas,
    this.observaciones,
    this.errorMessage,
    this.lastSyncAttempt,
    this.syncRetries = 0,
  })  : batchUuid = batchUuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        lecturas = lecturas ?? [];

  /// Serializa para envío al backend (POST /api/v1/sync)
  Map<String, dynamic> toSyncRequest() {
    return {
      'batch_uuid': batchUuid,
      'device_id': deviceId,
      'technician_id': technicianId,
      'created_at': createdAt.toIso8601String(),
      'planilla_nombre': tipo.codigo,
      'readings': lecturas.map((l) => l.toJson()).toList(),
    };
  }

  /// Serializa para cache local (Hive)
  Map<String, dynamic> toJson() {
    return {
      'batch_uuid': batchUuid,
      'tipo': tipo.codigo,
      'device_id': deviceId,
      'technician_id': technicianId,
      'created_at': createdAt.toIso8601String(),
      'estado': estado.name,
      'lecturas': lecturas.map((l) => l.toJson()).toList(),
      'observaciones': observaciones,
      'error_message': errorMessage,
      'last_sync_attempt': lastSyncAttempt?.toIso8601String(),
      'sync_retries': syncRetries,
    };
  }

  /// Deserializa desde cache local
  factory Planilla.fromJson(Map<String, dynamic> json) {
    return Planilla(
      batchUuid: json['batch_uuid'] as String,
      tipo: TipoPlanilla.fromCodigo(json['tipo'] as String),
      deviceId: json['device_id'] as String,
      technicianId: json['technician_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      estado: PlanillaEstado.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => PlanillaEstado.borrador,
      ),
      lecturas: (json['lecturas'] as List<dynamic>?)
              ?.map((l) => Lectura.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      observaciones: json['observaciones'] as String?,
      errorMessage: json['error_message'] as String?,
      lastSyncAttempt: json['last_sync_attempt'] != null
          ? DateTime.parse(json['last_sync_attempt'] as String)
          : null,
      syncRetries: json['sync_retries'] as int? ?? 0,
    );
  }

  // ===========================================================================
  // Métodos de gestión de lecturas
  // ===========================================================================

  /// Agrega una lectura al lote
  void agregarLectura(Lectura lectura) {
    lecturas.add(lectura);
  }

  /// Elimina una lectura por clientRowId
  void eliminarLectura(int clientRowId) {
    lecturas.removeWhere((l) => l.clientRowId == clientRowId);
  }

  /// Actualiza una lectura existente
  void actualizarLectura(Lectura lectura) {
    final index = lecturas.indexWhere((l) => l.clientRowId == lectura.clientRowId);
    if (index >= 0) {
      lecturas[index] = lectura;
    }
  }

  /// Obtiene el próximo clientRowId disponible
  int get nextClientRowId {
    if (lecturas.isEmpty) return 1;
    return lecturas.map((l) => l.clientRowId).reduce((a, b) => a > b ? a : b) + 1;
  }

  // ===========================================================================
  // Propiedades calculadas
  // ===========================================================================

  /// Total de lecturas en el lote
  int get totalLecturas => lecturas.length;

  /// ¿Está vacía?
  bool get isEmpty => lecturas.isEmpty;

  /// ¿Tiene lecturas?
  bool get isNotEmpty => lecturas.isNotEmpty;

  /// ¿Se puede enviar? (tiene lecturas y está en estado válido)
  bool get puedeEnviar =>
      isNotEmpty &&
      (estado == PlanillaEstado.borrador ||
          estado == PlanillaEstado.pendiente ||
          estado == PlanillaEstado.error);

  /// ¿Ya fue enviada exitosamente?
  bool get fueEnviada => estado == PlanillaEstado.enviada;

  /// Rango de fechas de las lecturas
  String get rangoFechas {
    if (isEmpty) return 'Sin lecturas';
    final fechas = lecturas.map((l) => l.measuredAt).toList()..sort();
    final desde = _formatDate(fechas.first);
    final hasta = _formatDate(fechas.last);
    return desde == hasta ? desde : '$desde - $hasta';
  }

  /// Instrumentos únicos en el lote
  Set<String> get instrumentosUnicos =>
      lecturas.map((l) => l.instrumentCode).toSet();

  /// Resumen para UI
  String get resumen =>
      '${tipo.displayName} • $totalLecturas lecturas • $rangoFechas';

  // ===========================================================================
  // Métodos de estado
  // ===========================================================================

  /// Marca como lista para enviar
  void marcarPendiente() {
    estado = PlanillaEstado.pendiente;
    errorMessage = null;
  }

  /// Marca como enviando
  void marcarEnviando() {
    estado = PlanillaEstado.enviando;
    lastSyncAttempt = DateTime.now();
    syncRetries++;
  }

  /// Marca como enviada exitosamente
  void marcarEnviada() {
    estado = PlanillaEstado.enviada;
    errorMessage = null;
  }

  /// Marca como error
  void marcarError(String mensaje) {
    estado = PlanillaEstado.error;
    errorMessage = mensaje;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  @override
  String toString() => 'Planilla($batchUuid, ${tipo.displayName}, $estado, $totalLecturas lecturas)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Planilla && other.batchUuid == batchUuid;

  @override
  int get hashCode => batchUuid.hashCode;
}
