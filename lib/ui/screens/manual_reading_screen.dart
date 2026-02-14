// ==============================================================================
// CEMPPSA Field App - ManualReadingScreen
// Pantalla de lecturas manuales (Casagrande, Freatímetros, Aforadores)
// ==============================================================================

import 'package:flutter/material.dart';
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
      _disposeInputs();
      _currentPlanilla = planilla;
      _selectedTipo = planilla.tipo;
      if (planilla.lecturas.isNotEmpty) {
        _batchDateTime = planilla.lecturas.first.measuredAt;
      }

      // Load controllers
      for (final lectura in planilla.lecturas) {
        if (!_controllers.containsKey(lectura.instrumentCode)) {
          _controllers[lectura.instrumentCode] = TextEditingController();
        }
        // Format value to remove trailing .0 if integer-like?
        // simple toString for now or specific formatting
        _controllers[lectura.instrumentCode]!.text = lectura.value.toString();
      }
    });
    _loadSchemaForType(planilla.tipo);
  }

  @override
  void dispose() {
    _disposeInputs();
    super.dispose();
  }

  void _disposeInputs() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
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
              onPressed: _sendPlanilla,
              icon: const Icon(Icons.send, color: Color(0xFF22C55E), size: 18),
              label: const Text('Enviar',
                  style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E).withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _selectedTipo == null ? _buildTipoSelector() : _buildBatchGrid(),
    );
  }

  // ... _buildTipoSelector ...

  // [MODIFIED] Grid Header
  // ... _buildBatchHeader ...

  // [MODIFIED] Grid Items with improved Input Row
  Widget _buildInstrumentGrid() {
    final instrumentos =
        _getInstrumentosForTipo(context.read<CatalogRepository>());

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
        final schemaVariable = _defaultSchemaVariable();
        final String? label = schemaVariable?.name;
        final String? unit = schemaVariable?.unit;

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
    final filledCount =
        _controllers.entries.where((e) => e.value.text.isNotEmpty).length;

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                minimumSize: const Size(70, 36),
              ),
              child: const Text('Limpiar',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: filledCount > 0 ? _saveDraft : null, // Now saves draft
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6), // Blue for draft
                disabledBackgroundColor: const Color(0xFF334155),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(80, 36),
              ),
              child: const Text(
                'Guardar Borrador',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... helper methods ...

  SchemaVariable? _defaultSchemaVariable() {
    final schema = _loadedSchema;
    if (schema == null || schema.variables.isEmpty) {
      return null;
    }
    for (final variable in schema.variables) {
      if (variable.isDefault) {
        return variable;
      }
    }
    return schema.variables.first;
  }

  String _resolveVariableCode(Instrumento inst) {
    final schemaVariable = _defaultSchemaVariable();
    if (schemaVariable != null && schemaVariable.code.trim().isNotEmpty) {
      return schemaVariable.code;
    }
    return inst.ingestaParameter ?? inst.defaultParameter;
  }

  String? _resolveVariableUnit(Instrumento inst) {
    final schemaVariable = _defaultSchemaVariable();
    if (schemaVariable != null && schemaVariable.unit.trim().isNotEmpty) {
      return schemaVariable.unit;
    }
    return inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit;
  }

  void _upsertReading({
    required String instrumentCode,
    required String parameter,
    required String rawValue,
    String? unit,
  }) {
    if (_currentPlanilla == null) return;
    final normalizedValue = rawValue.trim();
    if (normalizedValue.isEmpty) return;

    final existingIndex = _currentPlanilla!.lecturas.indexWhere(
      (l) => l.instrumentCode == instrumentCode,
    );
    final rowId = existingIndex >= 0
        ? _currentPlanilla!.lecturas[existingIndex].clientRowId
        : _currentPlanilla!.nextClientRowId;

    if (existingIndex >= 0) {
      _currentPlanilla!.lecturas.removeAt(existingIndex);
    }

    final lectura = Lectura.fromForm(
      clientRowId: rowId,
      instrumentCode: instrumentCode,
      parameter: parameter,
      unit: unit,
      rawValue: normalizedValue,
      measuredAt: _batchDateTime,
    );

    _currentPlanilla!.agregarLectura(lectura);
  }

  void _syncPlanillaFromInputs(List<Instrumento> instrumentos) {
    if (_currentPlanilla == null) return;
    _currentPlanilla!.lecturas.clear();

    for (final inst in instrumentos) {
      _upsertReading(
        instrumentCode: inst.codigo,
        parameter: _resolveVariableCode(inst),
        unit: _resolveVariableUnit(inst),
        rawValue: _controllers[inst.codigo]?.text ?? '',
      );
    }
  }

  // [NEW] Single Reading Save
  Future<void> _saveSingleReading(Instrumento inst, String rawValue) async {
    if (_currentPlanilla == null || rawValue.trim().isEmpty) return;

    _upsertReading(
      instrumentCode: inst.codigo,
      parameter: _resolveVariableCode(inst),
      unit: _resolveVariableUnit(inst),
      rawValue: rawValue,
    );
    _currentPlanilla!.estado = PlanillaEstado.borrador;

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

  // [MODIFIED] Send Logic (Top Button)
  Future<void> _sendPlanilla() async {
    if (_currentPlanilla == null) return;

    final catalog = context.read<CatalogRepository>();
    final instrumentos = _getInstrumentosForTipo(catalog);
    _syncPlanillaFromInputs(instrumentos);

    if (_currentPlanilla!.lecturas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para enviar')),
      );
      return;
    }

    _currentPlanilla!.marcarPendiente();
    await context.read<PlanillaRepository>().save(_currentPlanilla!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardando y enviando...')),
    );

    try {
      final syncService = context.read<SyncService>();
      final planillaRepo = context.read<PlanillaRepository>();

      final result = await syncService.retrySingle(
        _currentPlanilla!.batchUuid,
        repository: planillaRepo,
        catalog: catalog,
      );
      final success = result['success'] == true;
      final queuedOffline = result['queued_offline'] == true;

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Planilla enviada exitosamente'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context);
        return;
      }

      if (queuedOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin conexión: planilla guardada como pendiente para sincronizar.',
            ),
            backgroundColor: Color(0xFF64748B),
          ),
        );
        Navigator.pop(context);
        return;
      }

      final error = (result['error'] ?? syncService.lastError)?.toString();
      _handleSendError(error);
    } catch (e) {
      debugPrint('Error sending planilla: $e');
      if (mounted) {
        if (_looksLikeConnectivityError(e.toString())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sin conexión: planilla guardada como pendiente para sincronizar.',
              ),
              backgroundColor: Color(0xFF64748B),
            ),
          );
          Navigator.pop(context);
          return;
        }
        _handleSendError(e.toString());
      }
    }
  }

  bool _looksLikeConnectivityError(String raw) {
    final text = raw.toLowerCase();
    return text.contains('socketexception') ||
        text.contains('network is unreachable') ||
        text.contains('failed host lookup') ||
        text.contains('connection failed') ||
        text.contains('clientexception') ||
        text.contains('timed out');
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
    final familyId = _mapTipoToSchemaFamilyId(tipo);
    if (familyId == null) {
      if (!mounted) return;
      setState(() => _loadedSchema = null);
      return;
    }

    final schema =
        await context.read<CatalogRepository>().fetchMobileSchema(familyId);
    if (!mounted) return;
    setState(() => _loadedSchema = schema);
  }

  String? _mapTipoToSchemaFamilyId(TipoPlanilla tipo) {
    switch (tipo) {
      case TipoPlanilla.casagrande:
        return 'piezometros_casagrande';
      case TipoPlanilla.freatimetros:
        return 'freatimetros';
      case TipoPlanilla.aforadores:
        return 'aforadores';
      case TipoPlanilla.drenes:
        return 'drenes';
      default:
        return null;
    }
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
            Text('Errores de Validación',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: errors.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Color(0xFF334155)),
            itemBuilder: (ctx, index) {
              final err = errors[index];
              final code = err['instrument_code'] ?? 'N/A';
              final msg = err['message'] ?? 'Error desconocido';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(code,
                    style: const TextStyle(
                        color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
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
        title: const Text('Detalle del Error',
            style: TextStyle(color: Colors.white)),
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
    if (_currentPlanilla == null) return;
    final instrumentos =
        _getInstrumentosForTipo(context.read<CatalogRepository>());
    _syncPlanillaFromInputs(instrumentos);

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
    final all = catalog.all();
    List<Instrumento> instrumentos;

    switch (_selectedTipo!) {
      case TipoPlanilla.casagrande:
        instrumentos = all
            .where(
              (i) =>
                  i.familia == FamiliaInstrumento.casagrande ||
                  (i.familia == FamiliaInstrumento.piezometro &&
                      i.subfamilia == 'CASAGRANDE'),
            )
            .toList();
        break;
      case TipoPlanilla.freatimetros:
        instrumentos = all
            .where((i) => i.familia == FamiliaInstrumento.freatimetro)
            .toList();
        break;
      case TipoPlanilla.aforadores:
        instrumentos = all.where((i) => _isAforadorWithoutDren(i)).toList();
        break;
      case TipoPlanilla.drenes:
        instrumentos = all.where(_isDren).toList();
        break;
      default:
        return [];
    }

    instrumentos.sort((a, b) => a.codigo.compareTo(b.codigo));
    return instrumentos;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'Planillas de mediciones',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Text(
              'Carga manual para planillas operativas: Casagrande, '
              'Freatimetros, Aforadores y Drenes.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          _FamilyCard(
            title: 'Casagrande',
            subtitle: 'Piezometros manuales',
            icon: Icons.waves_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => _selectFamily(TipoPlanilla.casagrande),
          ),
          const SizedBox(height: 12),
          _FamilyCard(
            title: 'Freatimetros',
            subtitle: 'Lectura de nivel freatico',
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF06B6D4),
            onTap: () => _selectFamily(TipoPlanilla.freatimetros),
          ),
          const SizedBox(height: 12),
          _FamilyCard(
            title: 'Aforadores',
            subtitle: 'Lecturas de caudal y altura',
            icon: Icons.speed_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () => _selectFamily(TipoPlanilla.aforadores),
          ),
          const SizedBox(height: 12),
          _FamilyCard(
            title: 'Drenes',
            subtitle: 'Lecturas de drenes (DC)',
            icon: Icons.filter_alt_rounded,
            color: const Color(0xFF22C55E),
            onTap: () => _selectFamily(TipoPlanilla.drenes),
          ),
        ],
      ),
    );
  }

  bool _isDren(Instrumento instrumento) {
    final code = CodigoHelper.canonicalize(instrumento.codigo);
    return code.startsWith('DC');
  }

  bool _isAforadorWithoutDren(Instrumento instrumento) {
    return instrumento.familia == FamiliaInstrumento.aforador &&
        !_isDren(instrumento);
  }

  Future<void> _selectFamily(TipoPlanilla tipo) async {
    setState(() {
      _disposeInputs();
      _selectedTipo = tipo;
      _batchDateTime = DateTime.now();
      _currentPlanilla = Planilla(
        tipo: tipo,
        deviceId: AppConfig.deviceId ?? 'unknown-device',
        technicianId: AppConfig.technicianId ?? 'unknown-tech',
        technicianName: AppConfig.technicianName,
        createdAt: DateTime.now(),
        lecturas: [],
      )..estado = PlanillaEstado.borrador;
      _loadedSchema = null;
    });
    await _loadSchemaForType(tipo);
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
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x333B82F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedTipo!.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: _confirmCancel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickBatchDateTime,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.grey, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Medicion: ${_formatDateTime(_batchDateTime)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.edit, color: Colors.grey, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBatchDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _batchDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_batchDateTime),
      );
      if (time != null) {
        setState(() {
          _batchDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _confirmCancel() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Salir?', style: TextStyle(color: Colors.white)),
        content: const Text('Se perderán los cambios no guardados.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir')),
        ],
      ),
    );

    if (shouldPop == true && mounted) {
      setState(() {
        _disposeInputs();
        _batchDateTime = DateTime.now();
        _selectedTipo = null;
        _currentPlanilla = null;
        _loadedSchema = null;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              customUnit ?? instrumento.defaultUnit,
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
            icon: const Icon(Icons.save_as_outlined,
                color: Color(0xFF3B82F6), size: 20),
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

class _FamilyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FamilyCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBgColor = Color.fromRGBO(
      color.red,
      color.green,
      color.blue,
      0.15,
    );

    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}
