// ==============================================================================
// CEMPPSA Field App - CR10XBatchScreen
// Pantalla de carga masiva CR10X (contingencia cuando falla automático)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/instrumento.dart';
import '../../data/models/lectura.dart';
import '../../data/models/planilla.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/planilla_repository.dart';
import '../../services/sync_service.dart'; // [NEW]
import 'dart:convert'; // [NEW]
import '../../core/config.dart';

class CR10XBatchScreen extends StatefulWidget {
  const CR10XBatchScreen({super.key});

  @override
  State<CR10XBatchScreen> createState() => _CR10XBatchScreenState();
}

class _CR10XBatchScreenState extends State<CR10XBatchScreen> {
  TipoPlanilla? _selectedTipo;
  String? _selectedEje;
  Planilla? _currentPlanilla;
  DateTime _batchDateTime = DateTime.now();

  // Controladores para entrada rápida en grid
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
      // Infer axis or other properties if needed?
      // CR10X types: Piezometers have Axis. 
      // If Piezometer, we might need to set _selectedEje?
      // But _currentPlanilla doesn't store 'Eje' explicitly, it's in the instrument code prefix maybe or subfamilia.
      // We can iterate readings to see instruments, query catalog, get subfamilia 'EJE_A'.
      
      _loadControllersFromDraft(planilla);
    });
  }

  void _loadControllersFromDraft(Planilla planilla) {
    // Attempt to infer EJE if piezometers
    if (planilla.tipo == TipoPlanilla.cr10xPiezometros && planilla.lecturas.isNotEmpty) {
      // Find first instrument
      final code = planilla.lecturas.first.instrumentCode;
      final catalog = context.read<CatalogRepository>();
      final inst = catalog.byCode(code);
      if (inst != null && (inst.subfamilia?.startsWith('EJE_') ?? false)) {
        _selectedEje = inst.subfamilia?.split('_').last;
      }
    }

    for (final lectura in planilla.lecturas) {
      if (!_controllers.containsKey(lectura.instrumentCode)) {
        _controllers[lectura.instrumentCode] = TextEditingController();
      }
      _controllers[lectura.instrumentCode]!.text = lectura.value.toString();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('CR10X'),
        elevation: 0,
        actions: [
          if (_currentPlanilla != null)
            TextButton.icon(
              onPressed: _sendPlanilla, // [MODIFIED] Now triggers Send
              icon: const Icon(Icons.send, color: Color(0xFF22C55E), size: 18),
              label: const Text('Enviar', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 13)),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _selectedTipo == null
          ? _buildFamilySelector()
          : _buildBatchGrid(),
    );
  }

  // ===========================================================================
  // Selector de familia CR10X
  // ===========================================================================

  Widget _buildFamilySelector() {
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

          // Piezómetros CV
          _FamilyCard(
            title: 'Piezómetros',
            subtitle: 'PA, PB, PC, PD, PE, PE1, PF, PG',
            icon: Icons.speed_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => _selectFamily(TipoPlanilla.cr10xPiezometros),
          ),
          const SizedBox(height: 12),

          // Asentímetros
          _FamilyCard(
            title: 'Asentímetros',
            subtitle: 'AD, AE1',
            icon: Icons.straighten_rounded,
            color: const Color(0xFFEC4899),
            onTap: () => _selectFamily(TipoPlanilla.cr10xAsentimetros),
          ),
          const SizedBox(height: 12),

          // Triaxiales
          _FamilyCard(
            title: 'Triaxiales',
            subtitle: 'J1-J15 (X, Y, Z)',
            icon: Icons.view_in_ar_rounded,
            color: const Color(0xFF14B8A6),
            onTap: () => _selectFamily(TipoPlanilla.cr10xTriaxiales),
          ),
          const SizedBox(height: 12),

          // Uniaxiales
          _FamilyCard(
            title: 'Uniaxiales',
            subtitle: 'Juntas uniaxiales',
            icon: Icons.linear_scale_rounded,
            color: const Color(0xFF06B6D4),
            onTap: () => _selectFamily(TipoPlanilla.cr10xUniaxiales),
          ),
          const SizedBox(height: 12),

          // Clinómetros
          _FamilyCard(
            title: 'Clinómetros',
            subtitle: 'Muro colado',
            icon: Icons.rotate_right_rounded,
            color: const Color(0xFF6366F1),
            onTap: () => _selectFamily(TipoPlanilla.cr10xClinometros),
          ),
          const SizedBox(height: 12),

          // Termómetros
          _FamilyCard(
            title: 'Termómetros',
            subtitle: 'TE, TG, T0-T3',
            icon: Icons.thermostat_rounded,
            color: const Color(0xFFF97316),
            onTap: () => _selectFamily(TipoPlanilla.cr10xTermometros),
          ),
          const SizedBox(height: 12),

          // Celdas de presión
          _FamilyCard(
            title: 'Celdas de presión',
            subtitle: 'TE, TG',
            icon: Icons.compress_rounded,
            color: const Color(0xFF10B981),
            onTap: () => _selectFamily(TipoPlanilla.cr10xCeldasPresion),
          ),
          const SizedBox(height: 12),

          // Barómetro
          _FamilyCard(
            title: 'Barómetro',
            subtitle: 'Presión atmosférica',
            icon: Icons.air_rounded,
            color: const Color(0xFF0EA5E9),
            onTap: () => _selectFamily(TipoPlanilla.cr10xBarometro),
          ),
        ],
      ),
    );
  }

  void _selectFamily(TipoPlanilla tipo) {
    setState(() {
      _selectedTipo = tipo;
      _selectedEje = null;
      _currentPlanilla = Planilla(
        tipo: tipo,
        deviceId: AppConfig.deviceId ?? 'unknown',
        technicianId: AppConfig.technicianId ?? 'tecnico',
      );
    });
  }

  // ===========================================================================
  // Grid de entrada masiva
  // ===========================================================================

  Widget _buildBatchGrid() {
    return Column(
      children: [
        // Header con fecha global
        _buildBatchHeader(),

        // Selector de eje (para piezómetros y asentímetros)
        if (_selectedTipo == TipoPlanilla.cr10xPiezometros || 
            _selectedTipo == TipoPlanilla.cr10xAsentimetros)
          _buildEjeSelector(),

        // Grid de instrumentos
        Expanded(
          child: _buildInstrumentGrid(),
        ),

        // Footer con acciones
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x33F59E0B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedTipo!.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B),
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
          // Fecha/hora global para todo el lote
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
                      'Medición: ${_formatDateTime(_batchDateTime)}',
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

  Widget _buildEjeSelector() {
    // Define axes based on type
    final List<String> ejes;
    if (_selectedTipo == TipoPlanilla.cr10xAsentimetros) {
      ejes = ['D', 'E1']; // Asentímetros only D & E1
    } else {
      // Piezometers
      ejes = ['A', 'B', 'C', 'D', 'E', 'E1', 'F', 'G'];
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ejes.length,
        itemBuilder: (ctx, index) {
          final eje = ejes[index];
          final isSelected = _selectedEje == eje;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('Eje $eje'),
              selected: isSelected,
              onSelected: (v) => setState(() => _selectedEje = v ? eje : null),
              backgroundColor: const Color(0xFF1E293B),
              selectedColor: const Color(0x4D8B5CF6),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF334155),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstrumentGrid() {
    final instrumentos = _getInstrumentosForGrid();

    // Require axis selection for Piezo & Asentimetro
    final needsAxis = _selectedTipo == TipoPlanilla.cr10xPiezometros || 
                      _selectedTipo == TipoPlanilla.cr10xAsentimetros;

    if (needsAxis && _selectedEje == null) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.arrow_upward, size: 48, color: Colors.grey[700]),
             const SizedBox(height: 16),
             Text(
               'Seleccioná un eje arriba',
               style: TextStyle(color: Colors.grey[500]),
             ),
           ],
         ),
       );
    }
    
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
        return _InstrumentInputRow(
          instrumento: inst,
          controller: _getController(inst.codigo),
          focusNode: _getFocusNode(inst.codigo),
          onSubmitted: () => _focusNext(instrumentos, index),
          onSave: (val) => _saveSingleReading(inst, val),
        );
      },
    );
  }

  List<Instrumento> _getInstrumentosForGrid() {
    final catalog = context.read<CatalogRepository>();

    switch (_selectedTipo) {
      case TipoPlanilla.cr10xPiezometros:
      case TipoPlanilla.cr10xAsentimetros:
        if (_selectedEje == null) return [];
        final subfamilia = 'EJE_${_selectedEje!}';
        final filtered = catalog.codigosPorSubfamilia(subfamilia)
            .map((c) => catalog.byCode(c))
            .where((i) => i != null && !i.esManual)
            .cast<Instrumento>()
            .toList();
        
        // Additional filter by family to distinguish Piezo vs Asentimetro (both use EJE_D)
        // EJE_D can contain both PA... and AD...
        // So we strictly filter by selected family type
        final targetFamily = _selectedTipo == TipoPlanilla.cr10xPiezometros
            ? FamiliaInstrumento.piezometro
            : FamiliaInstrumento.asentimetro;
            
        return filtered.where((i) => i.familia == targetFamily).toList();

      case TipoPlanilla.cr10xTriaxiales:
        // Ensure all axes shown. Logic already groups nothing, just returns all.
        // It should match JxxX, JxxY, JxxZ etc.
        return catalog.byFamilia(FamiliaInstrumento.triaxial);

      case TipoPlanilla.cr10xUniaxiales:
        return catalog.byFamilia(FamiliaInstrumento.uniaxial);

      case TipoPlanilla.cr10xTermometros:
        return catalog.byFamilia(FamiliaInstrumento.termometro);

      case TipoPlanilla.cr10xClinometros:
        return catalog.byFamilia(FamiliaInstrumento.clinometro);

      case TipoPlanilla.cr10xBarometro:
        return catalog.byFamilia(FamiliaInstrumento.barometro);

      case TipoPlanilla.cr10xCeldasPresion:
        return catalog.byFamilia(FamiliaInstrumento.celdaPresion);

      default:
        return [];
    }
  }

  TextEditingController _getController(String codigo) {
    if (!_controllers.containsKey(codigo)) {
      _controllers[codigo] = TextEditingController();
    }
    return _controllers[codigo]!;
  }

  FocusNode _getFocusNode(String codigo) {
    if (!_focusNodes.containsKey(codigo)) {
      _focusNodes[codigo] = FocusNode();
    }
    return _focusNodes[codigo]!;
  }

  void _focusNext(List<Instrumento> instrumentos, int currentIndex) {
    if (currentIndex < instrumentos.length - 1) {
      final nextCode = instrumentos[currentIndex + 1].codigo;
      _focusNodes[nextCode]?.requestFocus();
    }
  }

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
              onPressed: filledCount > 0 ? _saveDraft : null, // [MODIFIED]
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6), // [MODIFIED] Blue
                disabledBackgroundColor: const Color(0xFF334155),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(80, 36),
              ),
              child: const Text(
                'Guardar Borrador', // [MODIFIED]
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Acciones
  // ===========================================================================

  // [NEW] Single Reading Save
  Future<void> _saveSingleReading(Instrumento inst, String rawValue) async {
    if (rawValue.isEmpty) return;

    if (_currentPlanilla == null) return;
    
    // Ensure we don't duplicate logic but we do need a 'clientRowId'.
    // In batch logic, we usually rebuilt the whole list.
    // For single save, we want to update or add.
    
    final parameter = inst.ingestaParameter ?? inst.defaultParameter;
    
    // Check if exists
    final existingIndex = _currentPlanilla!.lecturas.indexWhere(
      (l) => l.instrumentCode == inst.codigo && l.parameter == parameter
    );

    final lectura = Lectura.fromForm(
      clientRowId: existingIndex >= 0 
          ? _currentPlanilla!.lecturas[existingIndex].clientRowId 
          : _currentPlanilla!.nextClientRowId,
      instrumentCode: inst.codigo,
      parameter: parameter,
      unit: inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit,
      rawValue: rawValue,
      measuredAt: _batchDateTime,
    );

    if (existingIndex >= 0) {
      _currentPlanilla!.lecturas[existingIndex] = lectura;
    } else {
      _currentPlanilla!.agregarLectura(lectura);
    }
    
    _currentPlanilla!.estado = PlanillaEstado.borrador;
    await context.read<PlanillaRepository>().save(_currentPlanilla!);

    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lectura de ${inst.codigo} guardada'),
          backgroundColor: const Color(0xFF3B82F6),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
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
            date.year, date.month, date.day, time.hour, time.minute,
          );
        });
      }
    }
  }

  void _clearAll() {
    for (final c in _controllers.values) {
      c.clear();
    }
    setState(() {});
  }

  Future<void> _sendPlanilla() async {
    // 1. Validate if empty
    final instruments = _getInstrumentosForGrid();
    final hasValues = _controllers.values.any((c) => c.text.isNotEmpty);

    if (!hasValues && _currentPlanilla?.lecturas.isEmpty == true) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para enviar')),
      );
      return;
    }

    // 2. Save local pending
    // Rebuild readings from form to ensure latest values
    final instrumentos = _getInstrumentosForGrid();
    int clientRowId = 1;
    _currentPlanilla!.lecturas.clear(); 
    
    for (final inst in instrumentos) {
      final controller = _controllers[inst.codigo];
      if (controller != null && controller.text.isNotEmpty) {
        final lectura = Lectura.fromForm(
          clientRowId: clientRowId++,
          instrumentCode: inst.codigo,
          parameter: inst.ingestaParameter ?? inst.defaultParameter,
          unit: inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit,
          rawValue: controller.text,
          measuredAt: _batchDateTime,
        );
        _currentPlanilla!.agregarLectura(lectura);
      }
    }

    _currentPlanilla!.marcarPendiente();
    await context.read<PlanillaRepository>().save(_currentPlanilla!);

    // 3. Trigger Send via SyncService
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enviando planilla...')),
    );

    try {
      // Assuming SyncService is available via import (added previously)
      // Since it's a static method or singleton depending on implementation.
      // Checking import: 'import '../../services/sync_service.dart';'
      // ManualReadingScreen used: final syncService = context.read<SyncService>(); but Step 283 showed it's a class with methods.
      // Let's use Provider as likely setup.
      final syncService = context.read<SyncService>();
      final result = await syncService.retrySingle(
        _currentPlanilla!.batchUuid,
        repository: context.read<PlanillaRepository>(),
      );
      final success = result['success'] == true;
      final errorMsg = result['error'] as String?;

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Planilla enviada exitosamente'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context);
      } else {
        // Parse error details if available (422)
        if (errorMsg != null && errorMsg.contains('body=')) {
           _parseErrorDetails(errorMsg);
        } else {
           _showSimpleErrorDialog(errorMsg ?? 'Error desconocido');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSimpleErrorDialog('Error de conexión: $e');
      }
    }
  }
  
  void _parseErrorDetails(String errorMsg) {
      final bodyIndex = errorMsg.indexOf('body=');
      if (bodyIndex != -1) {
        final jsonStr = errorMsg.substring(bodyIndex + 5);
        try {
          final decoded = jsonDecode(jsonStr); 
          if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
            final detail = decoded['detail'];
            if (detail is Map && detail.containsKey('errors')) {
               final errorsList = detail['errors'];
               if (errorsList is List) {
                 _showValidationErrorsDialog(errorsList);
                 return;
               }
            }
          }
        } catch (_) {
          // Fallback
        }
      }
      _showSimpleErrorDialog(errorMsg);
  }

  Future<void> _saveDraft() async {
    final instrumentos = _getInstrumentosForGrid();
    int clientRowId = 1;

    // Reset and rebuild to ensure consistency or update existing?
    // For 'Save Draft' button usually means 'Save All Current State'.
    _currentPlanilla!.lecturas.clear();
    for (final inst in instrumentos) {
      final controller = _controllers[inst.codigo];
      if (controller != null && controller.text.isNotEmpty) {
        final lectura = Lectura.fromForm(
          clientRowId: clientRowId++,
          instrumentCode: inst.codigo,
          parameter: inst.ingestaParameter ?? inst.defaultParameter,
          unit: inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit,
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
          content: Text('Borrador guardado (local)'),
          backgroundColor: Color(0xFF3B82F6),
        ),
      );
    }
  }

  void _confirmCancel() {
    final hasData = _controllers.values.any((c) => c.text.isNotEmpty);

    if (!hasData) {
      setState(() {
        _selectedTipo = null;
        _selectedEje = null;
        _currentPlanilla = null;
      });
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Descartar cambios?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Tenés valores sin guardar.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Seguir'),
          ),
          TextButton(
            onPressed: () {
              _saveDraft();
              Navigator.pop(ctx);
              setState(() {
                _selectedTipo = null;
                _selectedEje = null;
                _currentPlanilla = null;
              });
            },
            child: const Text('Guardar borrador'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedTipo = null;
                _selectedEje = null;
                _currentPlanilla = null;
                for (final c in _controllers.values) {
                  c.clear();
                }
              });
            },
            child: const Text('Descartar', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Dialogs
  // ===========================================================================

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

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// Widgets auxiliares
// =============================================================================

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

class _InstrumentInputRow extends StatelessWidget {
  final Instrumento instrumento;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final Function(String) onSave; // [NEW]

  const _InstrumentInputRow({
    required this.instrumento,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onSave, // [NEW]
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
          // Código del instrumento
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
          // Input de valor
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => onSubmitted(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '0,00',
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
          // Unidad
          SizedBox(
            width: 30, // Reduced
            child: Text(
              instrumento.defaultUnit,
              style: TextStyle(
                fontSize: 11,
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
