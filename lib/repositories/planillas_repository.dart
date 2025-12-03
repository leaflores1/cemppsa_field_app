import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

import '../data/models/planilla.dart';
import '../data/models/lectura.dart';
import '../services/network_manager.dart';
import '../services/offline_storage.dart';
import '../config/app_config.dart';

class PlanillasRepository extends ChangeNotifier {
  static const String _boxName = 'planillas_v1';

  final _uuid = const Uuid();
  final List<Planilla> _items = [];

  final NetworkManager net;
  final OfflineStorage offline;

  late final Box _box;

  PlanillasRepository({required this.net, required this.offline});

  /// Carga planillas persistidas desde Hive al iniciar la app.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _items.clear();

    for (final value in _box.values) {
      if (value is Map) {
        try {
          final p = Planilla.fromJson(Map<String, dynamic>.from(value));
          _items.add(p);
        } catch (e) {
          debugPrint('Error leyendo planilla almacenada: $e');
        }
      }
    }
    notifyListeners();
  }

  bool _esEditable(Planilla p) => p.estado == PlanillaEstado.draft;

  void _save(Planilla p) {
    _box.put(p.id, p.toJson());
  }

  void _delete(String id) {
    _box.delete(id);
  }

  // -------- Crear nueva planilla en borrador --------
  String createDraft({required String tipoMedicion, required String tecnico}) {
    final id = _uuid.v4();
    final p = Planilla(
      id: id,
      tipoMedicion: tipoMedicion,
      fecha: DateTime.now(),
      tecnico: tecnico.isEmpty ? 'Técnico' : tecnico,
      estado: PlanillaEstado.draft,
      lecturas: <Lectura>[],
    );

    _items.add(p);
    _save(p);
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

  // -------- Operaciones sobre lecturas (solo en borrador) --------
  void addLectura(String planillaId, Lectura lectura) {
    final p = findById(planillaId);
    if (p == null || !_esEditable(p)) return;
    p.lecturas.add(lectura);
    _save(p);
    notifyListeners();
  }

  void updateLectura(String planillaId, int index, Lectura updated) {
    final p = findById(planillaId);
    if (p == null || !_esEditable(p)) return;
    if (index < 0 || index >= p.lecturas.length) return;
    p.lecturas[index] = updated;
    _save(p);
    notifyListeners();
  }

  void deleteLectura(String planillaId, int index) {
    final p = findById(planillaId);
    if (p == null || !_esEditable(p)) return;
    if (index < 0 || index >= p.lecturas.length) return;
    p.lecturas.removeAt(index);
    _save(p);
    notifyListeners();
  }

  // Marca como 'sent' todas las planillas cuyos IDs estén en la lista.
  void markAsSentBatchIds(List<String> ids) {
    bool changed = false;
    for (final p in _items) {
      if (ids.contains(p.id) && p.estado != PlanillaEstado.sent) {
        p.estado = PlanillaEstado.sent;
        _save(p);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  // -------- Envío / Sync --------
  Future<void> enviarPlanilla(String id) async {
    final p = findById(id);
    if (p == null) return;
    if (p.estado != PlanillaEstado.draft) return;

    p.estado = PlanillaEstado.sending;
    _save(p);
    notifyListeners();

    final base = net.currentBaseUrl;

    // Si hay base resolvida, intento envío directo
    if (net.isOnline && base != null) {
      final ok = await _postPlanilla(p, base);
      if (ok) {
        p.estado = PlanillaEstado.sent;
        _save(p);
        notifyListeners();
        return;
      }
      // si falló el POST pese a estar online, encolá para reintentar
    }

    // Encolar y reintentar cuando haya red
    await offline.enqueue(p);
    await offline.flushIfPossible(net);
    _save(p); // sigue en 'sending' hasta que SyncService lo marque 'sent'
    notifyListeners();
  }

  Future<bool> _postPlanilla(Planilla p, String baseUrl) async {
    final uri = Uri.parse('$baseUrl${AppConfig.apiSyncPath}');
    final body = jsonEncode(p.toJson()); // Respeta tu modelo SyncBatchIn

    try {
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(AppConfig.httpTimeout);

      if (res.statusCode == 200 || res.statusCode == 201) return true;

      debugPrint('POST ${AppConfig.apiSyncPath} -> ${res.statusCode}: ${res.body}');
      return false;
    } catch (e) {
      debugPrint('POST ${AppConfig.apiSyncPath} error: $e');
      return false;
    }
  }

  // Eliminar planilla (permitido en cualquier estado)
  bool deletePlanilla(String id) {
    final idx = _items.indexWhere((p) => p.id == id);
    if (idx == -1) return false;
    final p = _items.removeAt(idx);
    _delete(p.id);
    notifyListeners();
    return true;
  }

  // -------- Contadores para el Home --------
  int get countDrafts => byEstado(PlanillaEstado.draft).length;
  int get countSending => byEstado(PlanillaEstado.sending).length;
  int get countSent => byEstado(PlanillaEstado.sent).length;
}
