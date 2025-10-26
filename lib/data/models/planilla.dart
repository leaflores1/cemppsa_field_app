import 'package:flutter/foundation.dart';
import 'lectura.dart';

enum PlanillaEstado { draft, sending, sent }

@immutable
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
    this.estado = PlanillaEstado.draft,
    List<Lectura>? lecturas,
  }) : lecturas = lecturas ?? <Lectura>[];
}
