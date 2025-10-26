import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/planilla.dart';
import '../data/models/lectura.dart';

class PlanillasRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final List<Planilla> _items = [];

  PlanillasRepository() {
    // Datos de ejemplo estables
    for (var i = 1; i <= 6; i++) {
      _items.add(
        Planilla(
          id: _uuid.v4(),
          tipoMedicion: i.isOdd ? 'Piezómetros' : 'Freatímetros',
          fecha: DateTime.now().subtract(Duration(days: i)),
          tecnico: 'Tec. $i',
          estado: i == 1
              ? PlanillaEstado.sending
              : (i == 2 ? PlanillaEstado.sent : PlanillaEstado.draft),
          lecturas: [
            Lectura(instrumento: 'PP$i', valor: (3000 + i).toString()),
          ],
        ),
      );
    }
  }

  // -------- API unificada --------
  List<Planilla> all() => List.unmodifiable(_items);

  List<Planilla> byEstado(PlanillaEstado estado) =>
      _items.where((p) => p.estado == estado).toList();

  Planilla? findById(String id) {
    try {
      return _items.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void addLectura(String planillaId, Lectura lectura) {
    final p = findById(planillaId);
    if (p == null) return;
    p.lecturas.add(lectura);
    notifyListeners();
  }

  Future<void> enviarPlanilla(String id) async {
    final p = findById(id);
    if (p == null) return;
    if (p.estado == PlanillaEstado.sent) return;

    p.estado = PlanillaEstado.sending;
    notifyListeners();

    // Simula envío
    await Future<void>.delayed(const Duration(seconds: 1));
    p.estado = PlanillaEstado.sent;
    notifyListeners();
  }

  // Contadores para el home
  int get countDrafts => byEstado(PlanillaEstado.draft).length;
  int get countSending => byEstado(PlanillaEstado.sending).length;
  int get countSent => byEstado(PlanillaEstado.sent).length;
}
