import 'package:uuid/uuid.dart';
import 'lectura.dart';

enum PlanillaEstado { draft, sending, sent }

class Planilla {
  final String id;
  final String tipoMedicion;
  final DateTime fecha;
  final String tecnico;
  PlanillaEstado estado;
  final List<Lectura> lecturas;

  Planilla({
    required this.id,
    required this.tipoMedicion,
    required this.fecha,
    required this.tecnico,
    required this.estado,
    List<Lectura>? lecturas,
  }) : lecturas = List<Lectura>.from(lecturas ?? const []);

  factory Planilla.fromJson(Map<String, dynamic> json) => Planilla(
        id: json['batch_uuid'] ??
            json['id'] ??
            const Uuid().v4(),

        /// 🔥 NOMBRE DE PLANILLA: SUPER COMPATIBLE
        tipoMedicion: json['tipo_medicion'] // formato nuevo
                ?? json['planilla_nombre']  // formato viejo
                ?? json['instrument_code']  // usado antes en pruebas
                ?? 'Sin nombre',

        fecha: DateTime.tryParse(
                  json['created_at'] ?? json['fecha'] ?? '',
                ) ??
            DateTime.now(),

        tecnico: json['technician_id'] ?? json['tecnico'] ?? '',

        /// 👇 Lee el estado si existe; si no, vuelve a draft
        estado: _estadoFromString(json['estado'] ?? 'draft'),

        lecturas: (json['readings'] ?? json['lecturas'] ?? const [])
            .map<Lectura>(
              (e) => Lectura.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );

  /// 🔁 Serializa para FastAPI **y** para persistir en Hive
  Map<String, dynamic> toJson() => {
        "batch_uuid": id,
        "device_id": "android_${id.substring(0, 6)}",
        "technician_id": tecnico,
        "created_at": fecha.toUtc().toIso8601String(),

        // 👇 Lo que usa el backend y la consola
        "planilla_nombre": tipoMedicion,
        "tipo_medicion": tipoMedicion,

        // 👇 CLAVE: guardamos el estado para que no se pierda al reabrir la app
        "estado": _estadoToString(estado),

        "readings": lecturas.asMap().entries.map((entry) {
          final idx = entry.key;
          final l = entry.value;

          final json = l.toJson();
          json['client_row_id'] = idx + 1;
          return json;
        }).toList(),
      };

  // ===== Helpers de estado =====

  static PlanillaEstado _estadoFromString(String s) {
    switch (s) {
      case 'sending':
        return PlanillaEstado.sending;
      case 'sent':
        return PlanillaEstado.sent;
      case 'draft':
      default:
        return PlanillaEstado.draft;
    }
  }

  static String _estadoToString(PlanillaEstado e) {
    switch (e) {
      case PlanillaEstado.draft:
        return 'draft';
      case PlanillaEstado.sending:
        return 'sending';
      case PlanillaEstado.sent:
        return 'sent';
    }
  }
}
