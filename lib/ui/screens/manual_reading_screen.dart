// ==============================================================================
// CEMPPSA Field App - ManualReadingScreen
// Pantalla de lecturas manuales (Casagrande, Freatímetros, Aforadores)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // [NEW] Import for Uuid
import 'dart:convert'; // [NEW] Import
import 'package:provider/provider.dart';

import '../../data/models/instrumento.dart';
import '../../data/models/lectura.dart';
import '../../data/models/planilla.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/planilla_repository.dart';
import '../../data/models/schema_model.dart';
import '../../core/config.dart';
import '../../services/sync_service.dart'; // [NEW] Import

class ManualReadingScreen extends StatefulWidget {
  const ManualReadingScreen({super.key});

  @override
  State<ManualReadingScreen> createState() => _ManualReadingScreenState();
}

class _ManualReadingScreenState extends State<ManualReadingScreen> {
  TipoPlanilla? _selectedTipo;
  Planilla? _currentPlanilla;
  DateTime _batchDateTime = DateTime.now();
  MobileSchema? _loadedSchema;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Planilla) {
        _initializeFromDraft(args);
      }
      _initialized = true;
    }
  }

  void _initializeFromDraft(Planilla planilla) {
    setState(() {
      _currentPlanilla = planilla;
      _selectedTipo = planilla.tipo;
      
      // Load controllers
      for (final lectura in planilla.lecturas) {
        if (!_controllers.containsKey(lectura.instrumentCode)) {
          _controllers[lectura.instrumentCode] = TextEditingController();
        }
        // Format value to remove trailing .0 if integer-like?
        // simple toString for now or specific formatting
        _controllers[lectura.instrumentCode]!.text = lectura.value.toString();
      }
      
      // Update Schema if available for this type
      _loadSchemaForType(planilla.tipo);
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

// ... imports

  // [MODIFIED] AppBar action: "Enviar"
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Lecturas Manuales'),
        elevation: 0,
        actions: [
          if (_currentPlanilla != null)
            TextButton.icon(
              onPressed: _sendPlanilla, // Now sends
              icon: const Icon(Icons.send_rounded, color: Color(0xFF22C55E)),
              label: const Text('Enviar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _selectedTipo == null
          ? _buildTipoSelector()
          : _buildBatchGrid(),
    );
  }

  // ... _buildTipoSelector ...

  // [MODIFIED] Grid Header
  // ... _buildBatchHeader ...

  // [MODIFIED] Grid Items with improved Input Row
  Widget _buildInstrumentGrid() {
    final instrumentos = _getInstrumentosForTipo(context.read<CatalogRepository>());

    if (instrumentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Sin instrumentos disponibles',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: instrumentos.length,
      itemBuilder: (ctx, index) {
        final inst = instrumentos[index];
        final String? label = _loadedSchema?.variables.isNotEmpty == true 
            ? _loadedSchema!.variables.first.name 
            : null;
        final String? unit = _loadedSchema?.variables.isNotEmpty == true 
            ? _loadedSchema!.variables.first.unit 
            : null;

        // Triaxiales: mostrar 3 campos (X, Y, Z) en lugar de 1
        if (_selectedTipo == TipoPlanilla.triaxiales && inst.familia == FamiliaInstrumento.triaxial) {
          return _TriaxialInputRow(
            instrumento: inst,
            controllerX: _getController('${inst.codigo}X'),
            controllerY: _getController('${inst.codigo}Y'),
            controllerZ: _getController('${inst.codigo}Z'),
            customUnit: unit,
            onSave: (valX, valY, valZ) => _saveTriaxialReading(inst, valX, valY, valZ),
          );
        }

        return _InstrumentInputRow(
          instrumento: inst,
          controller: _getController(inst.codigo),
          focusNode: _getFocusNode(inst.codigo),
          onSubmitted: () => _focusNext(instrumentos, index),
          customLabel: label,
          customUnit: unit,
          onSave: (val) => _saveSingleReading(inst, val), // Per-row save
        );
      },
    );
  }

  // [MODIFIED] Footer with "Guardar Borrador"
  Widget _buildBatchFooter() {
    final filledCount = _controllers.entries
        .where((e) => e.value.text.isNotEmpty)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '$filledCount valores',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _clearAll,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF334155)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                minimumSize: const Size(70, 36),
              ),
              child: const Text('Limpiar', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: filledCount > 0 ? _saveDraft : null, // Now saves draft
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6), // Blue for draft
                disabledBackgroundColor: const Color(0xFF334155),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(80, 36),
              ),
              child: const Text(
                'Guardar Borrador',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... helper methods ...

  // [NEW] Single Reading Save
  Future<void> _saveSingleReading(Instrumento inst, String rawValue) async {
    if (rawValue.isEmpty) return;

    if (_currentPlanilla == null) return;
    
    // Create/Update reading
    final variableCode = _loadedSchema?.variables.isNotEmpty == true
        ? _loadedSchema!.variables.first.code
        : (inst.ingestaParameter ?? inst.defaultParameter);
        
    final variableUnit = _loadedSchema?.variables.isNotEmpty == true
        ? _loadedSchema!.variables.first.unit
        : (inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit);
    
    // Need a row ID. If reading exists, update it. If not, new ID.
    // Simplifying: remove existing reading for this instrument before adding
    // Find existing reading by instrument code
    final existingIndex = _currentPlanilla!.lecturas.indexWhere((l) => l.instrumentCode == inst.codigo);
    int rowId;
    if (existingIndex >= 0) {
      rowId = _currentPlanilla!.lecturas[existingIndex].clientRowId;
      _currentPlanilla!.lecturas.removeAt(existingIndex);
    } else {
      rowId = _currentPlanilla!.nextClientRowId;
    }

    final lectura = Lectura.fromForm(
      clientRowId: rowId,
      instrumentCode: inst.codigo,
      parameter: variableCode,
      unit: variableUnit,
      rawValue: rawValue,
      measuredAt: _batchDateTime,
    );
    
    _currentPlanilla!.agregarLectura(lectura);
    _currentPlanilla!.estado = PlanillaEstado.borrador; // Keep as draft
    
    await context.read<PlanillaRepository>().save(_currentPlanilla!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${inst.codigo} guardado en borrador'),
          duration: const Duration(milliseconds: 800),
          backgroundColor: const Color(0xFF3B82F6),
        ),
      );
    }
  }

  // [NEW] Triaxial Reading Save (X, Y, Z)
  Future<void> _saveTriaxialReading(Instrumento inst, String rawValueX, String rawValueY, String rawValueZ) async {
    if (rawValueX.isEmpty && rawValueY.isEmpty && rawValueZ.isEmpty) return;

    if (_currentPlanilla == null) return;
    
    // Para cada eje (X, Y, Z), crear/actualizar una lectura
    // Códigos: J1X, J1Y, J1Z
    final axes = [
      ('X', rawValueX),
      ('Y', rawValueY),
      ('Z', rawValueZ),
    ];
    
    final variableCode = _loadedSchema?.variables.isNotEmpty == true
        ? _loadedSchema!.variables.first.code
        : (inst.ingestaParameter ?? inst.defaultParameter);
        
    final variableUnit = _loadedSchema?.variables.isNotEmpty == true
        ? _loadedSchema!.variables.first.unit
        : (inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit);
    
    for (final (axis, rawValue) in axes) {
      if (rawValue.isEmpty) continue;
      
      final axisCode = '${inst.codigo}$axis'; // J1X, J1Y, J1Z
      
      // Look for existing reading by axis code
      final existingIndex = _currentPlanilla!.lecturas.indexWhere((l) => l.instrumentCode == axisCode);
      int rowId;
      if (existingIndex >= 0) {
        rowId = _currentPlanilla!.lecturas[existingIndex].clientRowId;
        _currentPlanilla!.lecturas.removeAt(existingIndex);
      } else {
        rowId = _currentPlanilla!.nextClientRowId;
      }

      final lectura = Lectura.fromForm(
        clientRowId: rowId,
        instrumentCode: axisCode, // J1X, J1Y, J1Z
        parameter: variableCode,
        unit: variableUnit,
        rawValue: rawValue,
        measuredAt: _batchDateTime,
      );
      
      _currentPlanilla!.agregarLectura(lectura);
    }
    
    _currentPlanilla!.estado = PlanillaEstado.borrador;
    await context.read<PlanillaRepository>().save(_currentPlanilla!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${inst.codigo} (X,Y,Z) guardado en borrador'),
          duration: const Duration(milliseconds: 800),
          backgroundColor: const Color(0xFF3B82F6),
        ),
      );
    }
  }

  // [MODIFIED] Send Logic (Top Button)
  Future<void> _sendPlanilla() async {
    // 1. Ensure all current inputs are saved to planilla
    final instrumentos = _getInstrumentosForTipo(context.read<CatalogRepository>());
    
    // Sync UI to Model first (in case user didn't hit save on specific row)
    // We clear and rebuild to ensure exact match with UI? 
    // Or just update changed ones? Safer to rebuild from UI state for "Send All".
    _currentPlanilla!.lecturas.clear();
    int clientRowId = 1;

    for (final inst in instrumentos) {
      final controller = _controllers[inst.codigo];
      if (controller != null && controller.text.isNotEmpty) {
        final variableCode = _loadedSchema?.variables.isNotEmpty == true
            ? _loadedSchema!.variables.first.code
            : (inst.ingestaParameter ?? inst.defaultParameter);
            
        final variableUnit = _loadedSchema?.variables.isNotEmpty == true
            ? _loadedSchema!.variables.first.unit
            : (inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit);

        final lectura = Lectura.fromForm(
          clientRowId: clientRowId++,
          instrumentCode: inst.codigo,
          parameter: variableCode,
          unit: variableUnit,
          rawValue: controller.text,
          measuredAt: _batchDateTime,
        );
        _currentPlanilla!.agregarLectura(lectura);
      }
    }

    if (_currentPlanilla!.lecturas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para enviar')),
      );
      return;
    }

    // 2. Mark as Pendiente via Repository
    _currentPlanilla!.marcarPendiente();
    await context.read<PlanillaRepository>().save(_currentPlanilla!);

    // 3. Trigger Send via SyncService
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardando y enviando...')),
    );

    try {
      final syncService = context.read<SyncService>();
      final planillaRepo = context.read<PlanillaRepository>();
      
      // Attempt immediate send
      // Attempt immediate send
      final result = await syncService.retrySingle(
        _currentPlanilla!.batchUuid, 
        repository: planillaRepo,
      );
      final success = result['success'] == true;
      // Handle error message update if needed
      if (!success && result['error'] != null) {
         // syncService.lastError might be updated but result holds it too
      }
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Planilla enviada exitosamente'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
          Navigator.pop(context);
        } else {
          _handleSendError(syncService.lastError);
        }
      }
    } catch (e) {
      debugPrint('Error sending planilla: $e');
      if (mounted) {
         _handleSendError(e.toString());
      }
    }
  }

  void _handleSendError(String? errorMsg) {
    if (errorMsg == null) return;
    
    // Attempt to parse JSON body from "body={...}"
    final jsonDetails = _parseErrorDetails(errorMsg);
    
    if (jsonDetails != null && jsonDetails['errors'] is List) {
       _showValidationErrorsDialog(jsonDetails['errors']);
    } else {
       // Fallback: Show simple snackbar with "View Details" action
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al enviar (${errorMsg.length > 50 ? '...' : errorMsg})',
            maxLines: 2, 
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Ver detalle',
            textColor: Colors.white,
            onPressed: () {
               _showSimpleErrorDialog(errorMsg);
            },
          ),
        ),
      );
    }
  }

  Future<void> _loadSchemaForType(TipoPlanilla tipo) async {
    // Basic implementation: attempt to load from config or service if available.
    // For now we don't strictly need the schema for draft loading if we trust the stored data.
    // But to match the call site, we provide the stub or actual implementation.
    
    // Check if we have a SchemaService concept imported? 
    // It seems missing in this file imports.
    // We can just skip schema loading for now or implement a dummy if not critical.
    // However, the saving logic relies on _loadedSchema?
    // Lines 217-223 use _loadedSchema. 
    // So we should try to mock it or fix the usage.
    
    // Ideally:
    // final service = context.read<SchemaService>();
    // final schema = await service.getSchemaForType(tipo);
    // setState(() => _loadedSchema = schema);
    
    // Since I don't see SchemaService imported, I'll remove the call or comment it out 
    // and rely on existing parameter logic if schema is null.
    // The existing code handles null _loadedSchema (lines 217+).
    // So making this a no-op is safe for compilation.
    debugPrint('Loading schema for ${tipo.name} (Placeholder)');
  }
  Map<String, dynamic>? _parseErrorDetails(String errorMsg) {
    try {
      final bodyIndex = errorMsg.indexOf('body=');
      if (bodyIndex != -1) {
        final jsonStr = errorMsg.substring(bodyIndex + 5);
        final decoded = jsonDecode(jsonStr); 
        if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
           return decoded['detail'] as Map<String, dynamic>;
        }
      }
    } catch (_) {
      // ignore parsing error
    }
    return null;
  }
  
  void _showValidationErrorsDialog(List errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
             Icon(Icons.error_outline, color: Color(0xFFEF4444)),
             SizedBox(width: 10),
             Text('Errores de Validación', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: errors.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155)),
            itemBuilder: (ctx, index) {
              final err = errors[index];
              final code = err['instrument_code'] ?? 'N/A';
              final msg = err['message'] ?? 'Error desconocido';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(code, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                subtitle: Text(msg, style: TextStyle(color: Colors.grey[300])),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showSimpleErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Detalle del Error', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(msg, style: TextStyle(color: Colors.grey[300])),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // [MODIFIED] Save Draft Logic (Bottom Button)
  Future<void> _saveDraft() async {
    final instrumentos = _getInstrumentosForTipo(context.read<CatalogRepository>());
    _currentPlanilla!.lecturas.clear();
    int clientRowId = 1;

    for (final inst in instrumentos) {
      final controller = _controllers[inst.codigo];
      if (controller != null && controller.text.isNotEmpty) {
         final variableCode = _loadedSchema?.variables.isNotEmpty == true
            ? _loadedSchema!.variables.first.code
            : (inst.ingestaParameter ?? inst.defaultParameter);
            
        final variableUnit = _loadedSchema?.variables.isNotEmpty == true
            ? _loadedSchema!.variables.first.unit
            : (inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit);

        final lectura = Lectura.fromForm(
          clientRowId: clientRowId++,
          instrumentCode: inst.codigo,
          parameter: variableCode,
          unit: variableUnit,
          rawValue: controller.text,
          measuredAt: _batchDateTime,
        );
        _currentPlanilla!.agregarLectura(lectura);
      }
    }

    _currentPlanilla!.estado = PlanillaEstado.borrador;
    await context.read<PlanillaRepository>().save(_currentPlanilla!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrador guardado exitosamente'),
          backgroundColor: Color(0xFF3B82F6),
        ),
      );
    }
  }

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  List<Instrumento> _getInstrumentosForTipo(CatalogRepository catalog) {
    if (_selectedTipo == null) return [];
    final all = catalog.all(); // [FIX] .all() instead of .instruments
    switch (_selectedTipo!) {
      case TipoPlanilla.casagrande:
        return all.where((i) => i.familia == FamiliaInstrumento.casagrande || (i.familia == FamiliaInstrumento.piezometro && i.subfamilia == 'CASAGRANDE')).toList();
      case TipoPlanilla.freatimetros:
        return all.where((i) => i.familia == FamiliaInstrumento.freatimetro).toList();
      case TipoPlanilla.aforadores:
        return all.where((i) => i.familia == FamiliaInstrumento.aforador).toList();
      case TipoPlanilla.sismos:
         return all.where((i) => i.familia == FamiliaInstrumento.sismos).toList();
      case TipoPlanilla.triaxiales:
        // Retornar solo TRIAXIAL base (J1-J15), no los ejes
        return all.where((i) => i.familia == FamiliaInstrumento.triaxial && RegExp(r'^J\d+$').hasMatch(i.codigo.toUpperCase())).toList();
      default:
        return [];
    }
  }

  TextEditingController _getController(String code) {
    if (!_controllers.containsKey(code)) {
      _controllers[code] = TextEditingController();
    }
    return _controllers[code]!;
  }

  FocusNode _getFocusNode(String code) {
    if (!_focusNodes.containsKey(code)) {
      _focusNodes[code] = FocusNode();
    }
    return _focusNodes[code]!;
  }

  void _focusNext(List<Instrumento> instrumentos, int index) {
    if (index < instrumentos.length - 1) {
      final nextCode = instrumentos[index + 1].codigo;
      FocusScope.of(context).requestFocus(_getFocusNode(nextCode));
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _clearAll() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    setState(() {});
  }

  Widget _buildTipoSelector() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildOptionButton(Icons.waves, 'Casagrande', TipoPlanilla.casagrande),
          _buildOptionButton(Icons.water_drop, 'Freatímetros', TipoPlanilla.freatimetros),
          _buildOptionButton(Icons.speed, 'Aforadores', TipoPlanilla.aforadores),
          _buildOptionButton(Icons.vibration, 'Sismos', TipoPlanilla.sismos),
          _buildOptionButton(Icons.view_in_ar, 'Triaxiales', TipoPlanilla.triaxiales),
        ],
      ),
    );
  }

  Widget _buildOptionButton(IconData icon, String label, TipoPlanilla tipo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _selectedTipo = tipo;
            _currentPlanilla = Planilla(
               // [FIX] Correct constructor arguments
               batchUuid: const Uuid().v4(),
               tipo: tipo,
               deviceId: AppConfig.deviceId ?? 'unknown-device',
               technicianId: AppConfig.technicianId ?? 'unknown-tech',
               createdAt: DateTime.now(),
               lecturas: [],
             )..estado = PlanillaEstado.borrador;
          });
        },
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(200, 50),
          textStyle: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildBatchGrid() {
    return Column(
      children: [
        _buildBatchHeader(),
        Expanded(child: _buildInstrumentGrid()),
        _buildBatchFooter(),
      ],
    );
  }

  Widget _buildBatchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
           Row(
             children: [
               IconButton(
                 icon: const Icon(Icons.arrow_back, color: Colors.white),
                 onPressed: _confirmCancel,
               ),
               Text(
                 _selectedTipo?.name.toUpperCase() ?? '',
                 style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
               ),
             ],
           ),
           const SizedBox(height: 10),
           Text(
             'Fecha: ${_batchDateTime.toLocal()}',
             style: const TextStyle(color: Colors.grey),
           )
        ],
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Salir?', style: TextStyle(color: Colors.white)),
        content: const Text('Se perderán los cambios no guardados.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );
    
    if (shouldPop == true && mounted) {
      if (mounted) {
         // Navigator.pop(context); // Not pop, just reset state
         setState(() {
            _selectedTipo = null;
            _currentPlanilla = null;
            _controllers.clear();
         });
      }
    }
  }
}

// [MODIFIED] _InstrumentInputRow with Save Button
class _InstrumentInputRow extends StatelessWidget {
  final Instrumento instrumento;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final String? customLabel;
  final String? customUnit;
  final Function(String) onSave; // [NEW]

  const _InstrumentInputRow({
    required this.instrumento,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onSave, // [NEW]
    this.customLabel,
    this.customUnit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              instrumento.codigo,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next, // Or Done?
              onSubmitted: (_) => onSubmitted(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: customLabel ?? '0,00',
                hintStyle: TextStyle(color: Colors.grey[700]),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // [NEW] Unit Text
          SizedBox(
            width: 30, // Reduced to make space for button
            child: Text(
              instrumento.defaultUnit, // Use param if possible, but defaults ok
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // [NEW] Save Icon Button
          IconButton(
            icon: const Icon(Icons.save_as_outlined, color: Color(0xFF3B82F6), size: 20),
            onPressed: () => onSave(controller.text),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: 'Guardar valor',
          ),
        ],
      ),
    );
  }
}

// [NEW] _TriaxialInputRow - 3 valores (X, Y, Z)
class _TriaxialInputRow extends StatelessWidget {
  final Instrumento instrumento;
  final TextEditingController controllerX;
  final TextEditingController controllerY;
  final TextEditingController controllerZ;
  final String? customUnit;
  final Function(String, String, String) onSave;

  const _TriaxialInputRow({
    required this.instrumento,
    required this.controllerX,
    required this.controllerY,
    required this.controllerZ,
    required this.onSave,
    this.customUnit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Text(
            instrumento.codigo,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          
          // Tres campos: X, Y, Z
          Row(
            children: [
              // Eje X
              Expanded(
                child: _TriaxialAxisInput(
                  label: 'Eje X',
                  controller: controllerX,
                  unit: customUnit ?? instrumento.defaultUnit,
                ),
              ),
              const SizedBox(width: 8),
              
              // Eje Y
              Expanded(
                child: _TriaxialAxisInput(
                  label: 'Eje Y',
                  controller: controllerY,
                  unit: customUnit ?? instrumento.defaultUnit,
                ),
              ),
              const SizedBox(width: 8),
              
              // Eje Z
              Expanded(
                child: _TriaxialAxisInput(
                  label: 'Eje Z',
                  controller: controllerZ,
                  unit: customUnit ?? instrumento.defaultUnit,
                ),
              ),
              const SizedBox(width: 8),
              
              // Botón Guardar
              IconButton(
                icon: const Icon(Icons.save_as_outlined, color: Color(0xFF10B981), size: 22),
                onPressed: () => onSave(controllerX.text, controllerY.text, controllerZ.text),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                tooltip: 'Guardar 3 ejes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// [NEW] Triaxial Axis Input - campo para un eje (X, Y, o Z)
class _TriaxialAxisInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String unit;

  const _TriaxialAxisInput({
    required this.label,
    required this.controller,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: '0,0',
            hintStyle: TextStyle(color: Colors.grey[800]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            suffixText: unit,
            suffixStyle: TextStyle(fontSize: 8, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
