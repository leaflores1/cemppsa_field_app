import 'package:uuid/uuid.dart';
import 'lectura.dart';

enum PlanillaEstado { draft, sending, sent }

class Planilla {
  final String id;                 // uuid
  final String tipoMedicion;       // instrumento o tipo
  final DateTime fecha;            // fecha de creación
  final String tecnico;            // nombre del técnico
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
        id: json['batch_uuid'] as String? ??
            json['id'] as String? ??
            const Uuid().v4(),
        tipoMedicion:
            json['tipo_medicion'] as String? ?? json['instrument_code'] ?? '',
        fecha: DateTime.tryParse(json['created_at'] ?? json['fecha'] ?? '') ??
            DateTime.now(),
        tecnico: json['technician_id'] as String? ?? json['tecnico'] ?? '',
        estado: _estadoFromString(json['estado'] as String? ?? 'draft'),
        lecturas: (json['readings'] ?? json['lecturas'] ?? const [])
            .map<Lectura>(
                (e) => Lectura.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// 🔁 Serializa según el modelo SyncBatchIn de FastAPI
  Map<String, dynamic> toJson() => {
        "batch_uuid": id,
        "device_id": "android_${id.substring(0, 6)}", // identificador local
        "technician_id": tecnico,
        "created_at": fecha.toIso8601String(),
        "readings": lecturas.asMap().entries.map((entry) {
          final idx = entry.key;
          final l = entry.value;

          final json = l.toJson();

         
        // Forzamos client_row_id secuencial (1..N) para el backend
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

