import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/planilla.dart';
import '../data/models/lectura.dart';

class PlanillasRepository extends ChangeNotifier {
  final _uuid = const Uuid();
  final List<Planilla> _items = [];

  PlanillasRepository() {
    // Semilla de ejemplo
    for (var i = 1; i <= 3; i++) {
      _items.add(
        Planilla(
          id: _uuid.v4(),
          tipoMedicion: i.isOdd ? 'Piezómetros' : 'Freatímetro',
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

  // -------- Crear nueva planilla en borrador --------
  String createDraft({required String tipoMedicion, required String tecnico}) {
    final id = _uuid.v4();
    _items.add(
      Planilla(
        id: id,
        tipoMedicion: tipoMedicion,
        fecha: DateTime.now(),
        tecnico: tecnico.isEmpty ? 'Técnico' : tecnico,
        estado: PlanillaEstado.draft,
        lecturas: <Lectura>[],
      ),
    );
    notifyListeners();
    return id;
  }

  // -------- Queries --------
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

  // -------- Operaciones sobre lecturas --------
  void addLectura(String planillaId, Lectura lectura) {
    final p = findById(planillaId);
    if (p == null) return;
    p.lecturas.add(lectura);
    notifyListeners();
  }

  void updateLectura(String planillaId, int index, Lectura updated) {
    final p = findById(planillaId);
    if (p == null) return;
    if (index < 0 || index >= p.lecturas.length) return;
    p.lecturas[index] = updated;
    notifyListeners();
  }

  void deleteLectura(String planillaId, int index) {
    final p = findById(planillaId);
    if (p == null) return;
    if (index < 0 || index >= p.lecturas.length) return;
    p.lecturas.removeAt(index);
    notifyListeners();
  }

  // -------- Envío / Sync --------
  Future<void> enviarPlanilla(String id) async {
    final p = findById(id);
    if (p == null) return;
    if (p.estado == PlanillaEstado.sent) return;

    p.estado = PlanillaEstado.sending;
    notifyListeners();

    // Simulación de envío (3s para que la veas en "Enviando")
    await Future<void>.delayed(const Duration(seconds: 3));

    p.estado = PlanillaEstado.sent;
    notifyListeners();
  }

  bool deletePlanilla(String id) {
    final idx = _items.indexWhere((p) => p.id == id);
    if (idx == -1) return false;
    _items.removeAt(idx);
    notifyListeners();
    return true;
  }

  // -------- Contadores para el Home --------
  int get countDrafts => byEstado(PlanillaEstado.draft).length;
  int get countSending => byEstado(PlanillaEstado.sending).length;
  int get countSent => byEstado(PlanillaEstado.sent).length;
}
