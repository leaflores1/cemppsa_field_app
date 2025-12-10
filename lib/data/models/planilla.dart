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
        tipoMedicion: json['tipo_medicion']               // formato nuevo
                ?? json['planilla_nombre']                // formato viejo
                ?? json['instrument_code']                // usado antes en alguna prueba
                ?? 'Sin nombre',

        fecha: DateTime.tryParse(json['created_at'] ?? json['fecha'] ?? '') ??
            DateTime.now(),

        tecnico: json['technician_id'] ?? json['tecnico'] ?? '',

        estado: _estadoFromString(json['estado'] ?? 'draft'),

        lecturas: (json['readings'] ?? json['lecturas'] ?? const [])
            .map<Lectura>(
              (e) => Lectura.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );

        Map<String, dynamic> toJson() => {
        "batch_uuid": id,
        "device_id": "android_${id.substring(0, 6)}",
        "technician_id": tecnico,
        "created_at": fecha.toUtc().toIso8601String(),

        // 👇 CLAVE: lo que espera el backend
        "planilla_nombre": tipoMedicion,

        // opcional: lo dejamos por compatibilidad si alguna vez lo usás en otro lado
        "tipo_medicion": tipoMedicion,

        "readings": lecturas.asMap().entries.map((entry) {
          final idx = entry.key;
          final l = entry.value;

          final json = l.toJson();
          json['client_row_id'] = idx + 1;
          return json;
        }).toList(),
      };




  static PlanillaEstado _estadoFromString(String s) {
    switch (s) {
      case 'sending':
        return PlanillaEstado.sending;
      case 'sent':
        return PlanillaEstado.sent;
      default:
        return PlanillaEstado.draft;
    }
  }
}
