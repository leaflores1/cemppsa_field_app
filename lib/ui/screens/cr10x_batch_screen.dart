// ==============================================================================
// CEMPPSA Field App - CR10XBatchScreen
// Pantalla de carga masiva CR10X (contingencia cuando falla automatico)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../data/models/instrumento.dart';
import '../../data/models/lectura.dart';
import '../../data/models/planilla.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/planilla_repository.dart';
import '../../services/sync_service.dart';
import 'dart:convert';
import '../../core/config.dart';
import '../../utils/decimal_input.dart';
import '../../utils/network_errors.dart';
import '../widgets/catalog_freshness_banner.dart';
import '../widgets/out_of_range_review_sheet.dart';

class CR10XBatchScreen extends StatefulWidget {
  const CR10XBatchScreen({super.key});

  @override
  State<CR10XBatchScreen> createState() => _CR10XBatchScreenState();
}

class _CR10XBatchScreenState extends State<CR10XBatchScreen> {
  static const List<String> _triaxAxes = ['X', 'Y', 'Z'];
  static final List<String> _triaxBaseCodes =
      List<String>.generate(15, (index) => 'J${index + 1}');
  static const String _tempSuffix = '__temp';

  TipoPlanilla? _selectedTipo;
  String? _selectedEje;
  Planilla? _currentPlanilla;
  DateTime _batchDateTime = DateTime.now();

  // Controladores para entrada rapida en grid
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, String> _confirmedWarningRawByKey = {};
  final Set<String> _reviewHighlightedKeys = {};
  final Set<String> _loggedMissingCatalogCodes = {};

  bool _initialized = false;
  static const String _confirmedOutOfRangeNote =
      'Valor fuera de rango confirmado por tecnico en campo';

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
    if ((planilla.tipo == TipoPlanilla.cr10xPiezometros ||
            planilla.tipo == TipoPlanilla.cr10xAsentimetros) &&
        planilla.lecturas.isNotEmpty) {
      // Find first instrument
      final code = planilla.lecturas.first.instrumentCode;
      final catalog = context.read<CatalogRepository>();
      final inst = catalog.byCode(code);
      if (inst != null && (inst.subfamilia?.startsWith('EJE_') ?? false)) {
        _selectedEje = inst.subfamilia?.split('_').last;
      } else if (planilla.tipo == TipoPlanilla.cr10xPiezometros &&
          code.toUpperCase().startsWith('PC')) {
        _selectedEje = 'C';
      }
    }

    for (final lectura in planilla.lecturas) {
      final key = _controllerKeyForDraft(lectura);
      if (!_controllers.containsKey(key)) {
        _controllers[key] = TextEditingController();
      }
      _controllers[key]!.text = _controllerTextForLectura(lectura);
      if (lectura.advertenciaConfirmada == true && lectura.valorRaw != null) {
        _confirmedWarningRawByKey[
                _readingKey(lectura.instrumentCode, lectura.parameter)] =
            lectura.valorRaw!;
      }
    }
  }

  String _tempControllerKey(String codigo) => '$codigo$_tempSuffix';

  String _controllerKeyForDraft(Lectura lectura) {
    if (_selectedTipo == TipoPlanilla.cr10xTriaxiales) {
      final normalizedCode = CodigoHelper.canonicalize(lectura.instrumentCode);
      if (RegExp(r'^[A-Z0-9]+[XYZ]$').hasMatch(normalizedCode)) {
        return normalizedCode;
      }
      final parameter = (lectura.parameter ?? '').trim().toUpperCase();
      final axisMatch = RegExp(r'PERIODO_([XYZ])$').firstMatch(parameter);
      if (axisMatch != null) {
        return '${_triaxBaseCode(normalizedCode)}${axisMatch.group(1)!}';
      }
      return normalizedCode;
    }

    final isAsentimetroTemp = _selectedTipo == TipoPlanilla.cr10xAsentimetros &&
        (lectura.parameter ?? '').trim().toUpperCase() == 'TEMPERATURA';
    return isAsentimetroTemp
        ? _tempControllerKey(lectura.instrumentCode)
        : lectura.instrumentCode;
  }

  String _triaxBaseCode(String code) {
    final normalized = CodigoHelper.canonicalize(code);
    final axisMatch = RegExp(r'^(J\d+)[XYZT]$').firstMatch(normalized);
    if (axisMatch != null) {
      return axisMatch.group(1)!;
    }
    return normalized;
  }

  String _triaxAxisKey(String baseCode, String axis) =>
      '${_triaxBaseCode(baseCode)}$axis';

  @override
  void dispose() {
    _disposeInputs();
    super.dispose();
  }

  void _disposeInputs() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
    _confirmedWarningRawByKey.clear();
    _reviewHighlightedKeys.clear();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: _selectedTipo == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectedTipo != null) {
            _confirmCancel();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            title: const Text('CR10X'),
            elevation: 0,
            leading: _selectedTipo != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _confirmCancel,
                  )
                : null,
            actions: [
              if (_currentPlanilla != null)
                TextButton.icon(
                  onPressed: _hasInvalidInputs
                      ? null
                      : _sendPlanilla, // [MODIFIED] Now triggers Send
                  icon: const Icon(Icons.send,
                      color: Color(0xFF22C55E), size: 18),
                  label: const Text('Enviar',
                      style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF22C55E).withValues(alpha: 0.1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: _selectedTipo == null
              ? _buildFamilySelector()
              : _buildBatchGrid(),
        ));
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Text(
              '.dat automaticos = fuente de verdad. '
              'Usar esta carga solo para contraste/contingencia manual.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          // Piezometros CV
          _FamilyCard(
            title: 'Piezometros',
            subtitle: 'PA, PB, PC, PD, PE, PE1, PF, PG',
            icon: Icons.speed_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => _selectFamily(TipoPlanilla.cr10xPiezometros),
          ),
          const SizedBox(height: 12),

          // Asentimetros
          _FamilyCard(
            title: 'Asentimetros',
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

          // Clinometros
          _FamilyCard(
            title: 'Clinometros',
            subtitle: 'Muro colado',
            icon: Icons.rotate_right_rounded,
            color: const Color(0xFF6366F1),
            onTap: () => _selectFamily(TipoPlanilla.cr10xClinometros),
          ),
          const SizedBox(height: 12),

          // Limnimetros
          _FamilyCard(
            title: 'Limnimetros',
            subtitle: 'Nivel de agua',
            icon: Icons.water_rounded,
            color: const Color(0xFF06B6D4),
            onTap: () => _selectFamily(TipoPlanilla.cr10xLimnimetros),
          ),
          const SizedBox(height: 12),

          // Termometros
          _FamilyCard(
            title: 'Termometros',
            subtitle: 'TE, TG, T0-T3',
            icon: Icons.thermostat_rounded,
            color: const Color(0xFFF97316),
            onTap: () => _selectFamily(TipoPlanilla.cr10xTermometros),
          ),
          const SizedBox(height: 12),

          // Celdas de presion
          _FamilyCard(
            title: 'Celdas de presion',
            subtitle: 'CP, CQ',
            icon: Icons.compress_rounded,
            color: const Color(0xFF10B981),
            onTap: () => _selectFamily(TipoPlanilla.cr10xCeldasPresion),
          ),
          const SizedBox(height: 12),

          // Barometro
          _FamilyCard(
            title: 'Barometro',
            subtitle: 'Presion atmosferica',
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
      _disposeInputs();
      _selectedTipo = tipo;
      _selectedEje = null;
      _batchDateTime = DateTime.now();
      _currentPlanilla = Planilla(
        tipo: tipo,
        deviceId: AppConfig.deviceId ?? 'unknown',
        technicianId: AppConfig.technicianId ?? 'tecnico',
        technicianName: AppConfig.technicianName,
      );
    });
  }

  /// Obtiene el rango desde el catÃ¡logo local (sin requests en pantalla)
  InstrumentRange? _getRangeForInstrument(
      String codigo, String variableCodigo) {
    return context
        .read<CatalogRepository>()
        .rangeForInstrument(codigo, variableCodigo);
  }

  // ===========================================================================
  // Grid de entrada masiva
  // ===========================================================================

  Widget _buildBatchGrid() {
    return Column(
      children: [
        // Header con fecha global
        _buildBatchHeader(),

        // Selector de eje (para piezometros y asentimetros)
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
    final catalog = context.watch<CatalogRepository>();
    final syncService = context.watch<SyncService>();
    final freshnessInfo = CatalogFreshnessInfo.fromRepository(catalog);

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
          const SizedBox(height: 12),
          CatalogFreshnessBanner(
            info: freshnessInfo,
            onTap: () => _showCatalogFreshnessPanel(catalog, syncService),
          ),
        ],
      ),
    );
  }

  Widget _buildEjeSelector() {
    // Define axes based on type
    final List<String> ejes;
    if (_selectedTipo == TipoPlanilla.cr10xAsentimetros) {
      ejes = ['D', 'E1']; // Asentimetros only D & E1
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
              'Selecciona un eje arriba',
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

    final list = ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: instrumentos.length,
      itemBuilder: (ctx, index) {
        final inst = instrumentos[index];
        if (_selectedTipo == TipoPlanilla.cr10xTriaxiales) {
          final baseCode = _triaxBaseCode(inst.codigo);
          return _TriaxialInputRow(
            instrumentCode: baseCode,
            hasCatalogReference:
                context.read<CatalogRepository>().byCode(baseCode) != null,
            controllerX: _getController(_triaxAxisKey(baseCode, 'X')),
            controllerY: _getController(_triaxAxisKey(baseCode, 'Y')),
            controllerZ: _getController(_triaxAxisKey(baseCode, 'Z')),
            focusNodeX: _getFocusNode(_triaxAxisKey(baseCode, 'X')),
            focusNodeY: _getFocusNode(_triaxAxisKey(baseCode, 'Y')),
            focusNodeZ: _getFocusNode(_triaxAxisKey(baseCode, 'Z')),
            onXSubmitted: () =>
                _getFocusNode(_triaxAxisKey(baseCode, 'Y')).requestFocus(),
            onYSubmitted: () =>
                _getFocusNode(_triaxAxisKey(baseCode, 'Z')).requestFocus(),
            onZSubmitted: () => _focusNextTriaxial(instrumentos, index),
            onSave: (x, y, z) => _saveTriaxialReadings(inst, x, y, z),
            rangeX: _getRangeForInstrument(baseCode, 'EJE_X'),
            rangeY: _getRangeForInstrument(baseCode, 'EJE_Y'),
            rangeZ: _getRangeForInstrument(baseCode, 'EJE_Z'),
            isWarningConfirmedX: _isWarningConfirmed(
              _triaxAxisKey(baseCode, 'X'),
              'PERIODO_X',
              _getController(_triaxAxisKey(baseCode, 'X')).text,
            ),
            isWarningConfirmedY: _isWarningConfirmed(
              _triaxAxisKey(baseCode, 'Y'),
              'PERIODO_Y',
              _getController(_triaxAxisKey(baseCode, 'Y')).text,
            ),
            isWarningConfirmedZ: _isWarningConfirmed(
              _triaxAxisKey(baseCode, 'Z'),
              'PERIODO_Z',
              _getController(_triaxAxisKey(baseCode, 'Z')).text,
            ),
            needsReviewX: _reviewHighlightedKeys.contains(
              _readingKey(_triaxAxisKey(baseCode, 'X'), 'PERIODO_X'),
            ),
            needsReviewY: _reviewHighlightedKeys.contains(
              _readingKey(_triaxAxisKey(baseCode, 'Y'), 'PERIODO_Y'),
            ),
            needsReviewZ: _reviewHighlightedKeys.contains(
              _readingKey(_triaxAxisKey(baseCode, 'Z'), 'PERIODO_Z'),
            ),
          );
        }

        if (_selectedTipo == TipoPlanilla.cr10xAsentimetros) {
          return _AsentimetroInputRow(
            instrumento: inst,
            luController: _getController(inst.codigo),
            tempController: _getController(_tempControllerKey(inst.codigo)),
            luFocusNode: _getFocusNode(inst.codigo),
            tempFocusNode: _getFocusNode(_tempControllerKey(inst.codigo)),
            onPrimarySubmitted: () =>
                _getFocusNode(_tempControllerKey(inst.codigo)).requestFocus(),
            onTempSubmitted: () => _focusNext(instrumentos, index),
            onSave: (luValue, tempValue) =>
                _saveAsentimetroReadings(inst, luValue, tempValue),
            rangeLu: _getRangeForInstrument(inst.codigo, 'LECTURA_LU'),
            rangeTemp: _getRangeForInstrument(inst.codigo, 'TEMPERATURA'),
            isLuWarningConfirmed: _isWarningConfirmed(
              inst.codigo,
              'LECTURA_LU',
              _getController(inst.codigo).text,
            ),
            isTempWarningConfirmed: _isWarningConfirmed(
              inst.codigo,
              'TEMPERATURA',
              _getController(_tempControllerKey(inst.codigo)).text,
            ),
            needsReviewLu: _reviewHighlightedKeys
                .contains(_readingKey(inst.codigo, 'LECTURA_LU')),
            needsReviewTemp: _reviewHighlightedKeys
                .contains(_readingKey(inst.codigo, 'TEMPERATURA')),
          );
        }

        return _InstrumentInputRow(
          instrumento: inst,
          controller: _getController(inst.codigo),
          focusNode: _getFocusNode(inst.codigo),
          onSubmitted: () => _focusNext(instrumentos, index),
          onSave: (val) => _saveSingleReading(inst, val),
          unitLabel: _resolveInputUnitLabel(inst),
          range: _getRangeForInstrument(
              inst.codigo, _resolvePrimaryParameter(inst)),
          isWarningConfirmed: _isWarningConfirmed(
            inst.codigo,
            _resolvePrimaryParameter(inst),
            _getController(inst.codigo).text,
          ),
          needsReviewHighlight: _reviewHighlightedKeys.contains(
            _readingKey(inst.codigo, _resolvePrimaryParameter(inst)),
          ),
        );
      },
    );

    if (_selectedTipo != TipoPlanilla.cr10xTriaxiales) {
      return list;
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0x1A14B8A6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x4D14B8A6)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF14B8A6), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cada instrumento triaxial tiene 3 lecturas: Eje X, Eje Y y Eje Z.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: list),
      ],
    );
  }

  List<Instrumento> _getInstrumentosForGrid() {
    final catalog = context.read<CatalogRepository>();
    List<Instrumento> instrumentos;

    switch (_selectedTipo) {
      case TipoPlanilla.cr10xPiezometros:
      case TipoPlanilla.cr10xAsentimetros:
        if (_selectedEje == null) return [];
        final subfamilia = 'EJE_${_selectedEje!}';
        final byAxis = catalog
            .codigosPorSubfamilia(subfamilia)
            .map((c) => catalog.byCode(c))
            .where((i) => i != null)
            .cast<Instrumento>()
            .toList();

        if (_selectedTipo == TipoPlanilla.cr10xPiezometros) {
          instrumentos = byAxis
              .where((i) =>
                  i.familia == FamiliaInstrumento.piezometro && !i.esManual)
              .toList();
        } else {
          instrumentos = byAxis
              .where((i) =>
                  i.familia == FamiliaInstrumento.asentimetro && !i.esManual)
              .toList();
        }
        break;

      case TipoPlanilla.cr10xTriaxiales:
        instrumentos = _getTriaxialBaseInstrumentos(catalog);
        break;

      case TipoPlanilla.cr10xUniaxiales:
        instrumentos = catalog.byFamilia(FamiliaInstrumento.uniaxial);
        break;

      case TipoPlanilla.cr10xTermometros:
        instrumentos = catalog.byFamilia(FamiliaInstrumento.termometro);
        break;

      case TipoPlanilla.cr10xClinometros:
        instrumentos = catalog.byFamilia(FamiliaInstrumento.clinometro);
        break;

      case TipoPlanilla.cr10xLimnimetros:
        instrumentos = catalog.byFamilia(FamiliaInstrumento.limnimetro);
        break;

      case TipoPlanilla.cr10xBarometro:
        instrumentos = catalog.byFamilia(FamiliaInstrumento.barometro);
        break;

      case TipoPlanilla.cr10xCeldasPresion:
        instrumentos = catalog.byFamilia(FamiliaInstrumento.celdaPresion);
        break;

      default:
        return [];
    }

    final sorted = List<Instrumento>.from(instrumentos)
      ..sort((a, b) => a.codigo.compareTo(b.codigo));
    return sorted;
  }

  List<Instrumento> _getTriaxialBaseInstrumentos(CatalogRepository catalog) {
    final allTriaxiales =
        List<Instrumento>.from(catalog.byFamilia(FamiliaInstrumento.triaxial));
    final byBase = <String, Instrumento>{};

    for (final inst in allTriaxiales) {
      final base = _triaxBaseCode(inst.codigo);
      byBase.putIfAbsent(
        base,
        () => Instrumento(
          idInstrumento: inst.idInstrumento,
          codigo: base,
          nombre: inst.nombre,
          familia: FamiliaInstrumento.triaxial,
          subfamilia: inst.subfamilia,
          activo: inst.activo,
          defaultParameter: inst.defaultParameter,
          defaultUnit: inst.defaultUnit,
        ),
      );
    }

    for (final baseCode in _triaxBaseCodes) {
      byBase.putIfAbsent(baseCode, () {
        if (kDebugMode && _loggedMissingCatalogCodes.add(baseCode)) {
          debugPrint('Instrumento $baseCode no encontrado en catalogo');
        }
        return Instrumento.fromCode(baseCode);
      });
    }

    for (final baseCode in byBase.keys) {
      if (catalog.byCode(baseCode) == null &&
          kDebugMode &&
          _loggedMissingCatalogCodes.add(baseCode)) {
        debugPrint('Instrumento $baseCode no encontrado en catalogo');
      }
    }

    final items = byBase.values.toList()
      ..sort((a, b) => a.codigo.compareTo(b.codigo));
    return items;
  }

  TextEditingController _getController(String codigo) {
    if (!_controllers.containsKey(codigo)) {
      final controller = TextEditingController();
      controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      _controllers[codigo] = controller;
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

  void _focusNextTriaxial(List<Instrumento> instrumentos, int currentIndex) {
    if (currentIndex < instrumentos.length - 1) {
      final nextBase = _triaxBaseCode(instrumentos[currentIndex + 1].codigo);
      _focusNodes[_triaxAxisKey(nextBase, 'X')]?.requestFocus();
    }
  }

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
              onPressed: filledCount > 0 && !_hasInvalidInputs
                  ? _saveDraft
                  : null, // [MODIFIED]
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6), // [MODIFIED] Blue
                disabledBackgroundColor: const Color(0xFF334155),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(80, 36),
              ),
              child: const Text(
                'Guardar Borrador', // [MODIFIED]
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

  // ===========================================================================
  // Acciones
  // ===========================================================================

  // [NEW] Single Reading Save
  Future<void> _saveSingleReading(Instrumento inst, String rawValue) async {
    if (_currentPlanilla == null || rawValue.trim().isEmpty) return;
    _upsertReading(
      instrumento: inst,
      rawValue: rawValue,
      parameter: _resolvePrimaryParameter(inst),
      unit: _resolvePrimaryUnit(inst),
    );

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

  Future<void> _saveAsentimetroReadings(
    Instrumento inst,
    String rawLuValue,
    String rawTempValue,
  ) async {
    if (_currentPlanilla == null) return;
    final hasLu = rawLuValue.trim().isNotEmpty;
    final hasTemp = rawTempValue.trim().isNotEmpty;
    if (!hasLu && !hasTemp) return;

    _upsertReading(
      instrumento: inst,
      rawValue: rawLuValue,
      parameter: 'LECTURA_LU',
      unit: 'LU',
    );
    _upsertReading(
      instrumento: inst,
      rawValue: rawTempValue,
      parameter: 'TEMPERATURA',
      unit: 'Â°C',
    );

    _currentPlanilla!.estado = PlanillaEstado.borrador;
    await context.read<PlanillaRepository>().save(_currentPlanilla!);

    if (mounted) {
      final suffix = hasLu && hasTemp ? ' (LU + Temp)' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lectura de ${inst.codigo}$suffix guardada'),
          backgroundColor: const Color(0xFF3B82F6),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> _saveTriaxialReadings(
    Instrumento inst,
    String rawX,
    String rawY,
    String rawZ,
  ) async {
    if (_currentPlanilla == null) return;
    final values = <String, String>{'X': rawX, 'Y': rawY, 'Z': rawZ};
    if (values.values.every((v) => v.trim().isEmpty)) return;

    final baseCode = _triaxBaseCode(inst.codigo);
    for (final axis in _triaxAxes) {
      _upsertReading(
        instrumento: inst,
        instrumentCode: _triaxAxisKey(baseCode, axis),
        rawValue: values[axis] ?? '',
        parameter: 'PERIODO_$axis',
        unit: _resolveTriaxialUnit(inst),
        rangeInstrumentCode: baseCode,
        rangeVariableCode: 'EJE_$axis',
      );
    }

    _currentPlanilla!.estado = PlanillaEstado.borrador;
    await context.read<PlanillaRepository>().save(_currentPlanilla!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Lecturas triaxiales de ${_triaxBaseCode(inst.codigo)} guardadas'),
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

  void _clearAll() {
    for (final c in _controllers.values) {
      c.clear();
    }
    _confirmedWarningRawByKey.clear();
    _reviewHighlightedKeys.clear();
    setState(() {});
  }

  void _upsertReading({
    required Instrumento instrumento,
    String? instrumentCode,
    required String rawValue,
    String? parameter,
    String? unit,
    String? rangeInstrumentCode,
    String? rangeVariableCode,
  }) {
    if (_currentPlanilla == null) return;
    final normalizedValue = rawValue.trim();
    if (normalizedValue.isEmpty) return;
    final resolvedInstrumentCode = instrumentCode ?? instrumento.codigo;

    final resolvedParameter =
        (parameter ?? _resolvePrimaryParameter(instrumento)).trim();
    if (resolvedParameter.isEmpty) return;

    final normalizedParameter = resolvedParameter.toLowerCase();
    final existingIndex = _currentPlanilla!.lecturas.indexWhere(
      (l) =>
          l.instrumentCode == resolvedInstrumentCode &&
          (l.parameter ?? '').toLowerCase() == normalizedParameter,
    );
    final existingReading =
        existingIndex >= 0 ? _currentPlanilla!.lecturas[existingIndex] : null;
    final effectiveRangeInstrumentCode =
        rangeInstrumentCode ?? resolvedInstrumentCode;
    final effectiveRangeVariableCode =
        (rangeVariableCode ?? resolvedParameter).trim();
    final range = _getRangeForInstrument(
      effectiveRangeInstrumentCode,
      effectiveRangeVariableCode,
    );
    final parsedValue = Lectura.parseRawValue(normalizedValue);
    final hasRange = range?.hasRange == true;
    final fueraDeRango = parsedValue != null
        ? (hasRange ? range!.isOutOfRange(parsedValue) : null)
        : null;
    final advertenciaConfirmada = fueraDeRango == true &&
            _isWarningConfirmed(
              resolvedInstrumentCode,
              resolvedParameter,
              normalizedValue,
            )
        ? true
        : null;

    final lectura = Lectura.fromForm(
      clientRowId: existingIndex >= 0
          ? _currentPlanilla!.lecturas[existingIndex].clientRowId
          : _currentPlanilla!.nextClientRowId,
      instrumentCode: resolvedInstrumentCode,
      parameter: resolvedParameter,
      unit: unit ?? _resolvePrimaryUnit(instrumento),
      rawValue: normalizedValue,
      measuredAt: _batchDateTime,
      fueraDeRango: fueraDeRango,
      rangoMin: hasRange && parsedValue != null ? range!.min : null,
      rangoMax: hasRange && parsedValue != null ? range!.max : null,
      rangoVersion: hasRange && parsedValue != null ? range!.version : null,
      advertenciaConfirmada: advertenciaConfirmada,
      notes: _buildReadingNotes(
        warningConfirmed: advertenciaConfirmada == true,
        existingNotes: existingReading?.notes,
      ),
    );

    if (existingIndex >= 0) {
      _currentPlanilla!.lecturas[existingIndex] = lectura;
    } else {
      _currentPlanilla!.agregarLectura(lectura);
    }
  }

  void _syncPlanillaFromInputs(List<Instrumento> instrumentos) {
    if (_currentPlanilla == null) return;
    _currentPlanilla!.lecturas.clear();

    for (final inst in instrumentos) {
      if (_selectedTipo == TipoPlanilla.cr10xTriaxiales) {
        final baseCode = _triaxBaseCode(inst.codigo);
        for (final axis in _triaxAxes) {
          _upsertReading(
            instrumento: inst,
            instrumentCode: _triaxAxisKey(baseCode, axis),
            rawValue: _controllers[_triaxAxisKey(baseCode, axis)]?.text ?? '',
            parameter: 'PERIODO_$axis',
            unit: _resolveTriaxialUnit(inst),
            rangeInstrumentCode: baseCode,
            rangeVariableCode: 'EJE_$axis',
          );
        }
        continue;
      }

      if (_selectedTipo == TipoPlanilla.cr10xAsentimetros) {
        _upsertReading(
          instrumento: inst,
          rawValue: _controllers[inst.codigo]?.text ?? '',
          parameter: 'LECTURA_LU',
          unit: 'LU',
        );
        _upsertReading(
          instrumento: inst,
          rawValue: _controllers[_tempControllerKey(inst.codigo)]?.text ?? '',
          parameter: 'TEMPERATURA',
          unit: 'Â°C',
        );
        continue;
      }

      _upsertReading(
        instrumento: inst,
        rawValue: _controllers[inst.codigo]?.text ?? '',
        parameter: _resolvePrimaryParameter(inst),
        unit: _resolvePrimaryUnit(inst),
      );
    }
  }

  String _resolvePrimaryParameter(Instrumento instrumento) {
    if (_selectedTipo == TipoPlanilla.cr10xPiezometros) {
      return 'LECTURA_CR10X';
    }
    if (_selectedTipo == TipoPlanilla.cr10xAsentimetros) {
      return 'LECTURA_LU';
    }
    return instrumento.ingestaParameter ?? instrumento.defaultParameter;
  }

  String? _resolvePrimaryUnit(Instrumento instrumento) {
    if (_selectedTipo == TipoPlanilla.cr10xPiezometros) {
      return 'Hz';
    }
    if (_selectedTipo == TipoPlanilla.cr10xAsentimetros) {
      return 'LU';
    }
    return instrumento.ingestaParameter != null
        ? instrumento.ingestaUnit
        : instrumento.defaultUnit;
  }

  String? _resolveTriaxialUnit(Instrumento instrumento) {
    final unit = instrumento.ingestaUnit;
    if (unit == null || unit.trim().isEmpty) {
      return null;
    }
    return unit.trim();
  }

  String _resolveInputUnitLabel(Instrumento instrumento) {
    final resolved = _resolvePrimaryUnit(instrumento);
    if (resolved == null || resolved.trim().isEmpty) {
      return instrumento.defaultUnit;
    }
    return resolved;
  }

  Future<void> _sendPlanilla() async {
    if (_currentPlanilla == null) return;
    if (_hasInvalidInputs) {
      _showInvalidValuesMessage();
      return;
    }
    final hasValues = _controllers.values.any((c) => c.text.isNotEmpty);

    if (!hasValues && _currentPlanilla?.lecturas.isEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para enviar')),
      );
      return;
    }

    // Save local pending (always rebuild from current form state)
    final instrumentos = _getInstrumentosForGrid();
    final readyToContinue = await _ensureOutOfRangeConfirmation(instrumentos);
    if (!readyToContinue) {
      return;
    }
    if (!mounted) return;

    if (_currentPlanilla!.lecturas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para enviar')),
      );
      return;
    }

    _currentPlanilla!.marcarPendiente();
    await context.read<PlanillaRepository>().save(_currentPlanilla!);

    // 3. Trigger Send via SyncService
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enviando planilla...')),
    );

    try {
      final catalog = context.read<CatalogRepository>();
      final syncService = context.read<SyncService>();
      final result = await syncService.retrySingle(
        _currentPlanilla!.batchUuid,
        repository: context.read<PlanillaRepository>(),
        catalog: catalog,
      );
      final success = result['success'] == true;
      final queuedOffline = result['queued_offline'] == true;
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
      } else if (queuedOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin conexiÃ³n: planilla guardada como pendiente para sincronizar.',
            ),
            backgroundColor: Color(0xFF64748B),
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
        if (isConnectivityFailure(message: e.toString())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sin conexiÃ³n: planilla guardada como pendiente para sincronizar.',
              ),
              backgroundColor: Color(0xFF64748B),
            ),
          );
          Navigator.pop(context);
          return;
        }
        _showSimpleErrorDialog('Error de conexion: $e');
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
    if (_currentPlanilla == null) return;
    if (_hasInvalidInputs) {
      _showInvalidValuesMessage();
      return;
    }
    final instrumentos = _getInstrumentosForGrid();
    final readyToContinue = await _ensureOutOfRangeConfirmation(instrumentos);
    if (!readyToContinue) {
      return;
    }

    _currentPlanilla!.estado = PlanillaEstado.borrador;
    if (!mounted) return;
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

  Future<void> _confirmCancel() async {
    final hasData = _controllers.values.any((c) => c.text.isNotEmpty);

    if (!hasData) {
      setState(() {
        _disposeInputs();
        _batchDateTime = DateTime.now();
        _selectedTipo = null;
        _selectedEje = null;
        _currentPlanilla = null;
      });
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Descartar cambios?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Tenes valores sin guardar.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Seguir'),
          ),
          TextButton(
            onPressed: () async {
              await _saveDraft();
              if (!mounted || !ctx.mounted) return;
              Navigator.pop(ctx);
              setState(() {
                _disposeInputs();
                _batchDateTime = DateTime.now();
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
                _disposeInputs();
                _batchDateTime = DateTime.now();
                _selectedTipo = null;
                _selectedEje = null;
                _currentPlanilla = null;
              });
            },
            child: const Text('Descartar',
                style: TextStyle(color: Color(0xFFEF4444))),
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
            Text('Errores de Validacion',
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

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showCatalogFreshnessPanel(
    CatalogRepository catalog,
    SyncService syncService,
  ) {
    return showCatalogFreshnessDetailsSheet(
      context,
      info: CatalogFreshnessInfo.fromRepository(catalog),
      checkConnection: syncService.checkConnection,
      initialIsConnected: syncService.isConnected,
      isRefreshing: catalog.isSyncing,
      onRefreshRequested: () => _refreshCatalogFromMeasurement(catalog),
    );
  }

  Future<void> _refreshCatalogFromMeasurement(CatalogRepository catalog) async {
    final ok = await catalog.syncFromBackend();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(ok ? 'Catalogo actualizado' : 'Error al actualizar catalogo'),
        backgroundColor: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      ),
    );
  }

  String _controllerTextForLectura(Lectura lectura) {
    if (lectura.valorRaw != null) {
      return lectura.valorRaw!;
    }
    return lectura.value?.toString() ?? '';
  }

  String _readingKey(String instrumentCode, String? parameter) {
    final canonicalCode =
        CodigoHelper.canonicalize(instrumentCode.toUpperCase().trim());
    final normalizedParameter = (parameter ?? '').trim().toUpperCase();
    return '$canonicalCode|$normalizedParameter';
  }

  bool _isWarningConfirmed(
    String instrumentCode,
    String? parameter,
    String rawValue,
  ) {
    final normalizedValue = Lectura.normalizeRawValue(rawValue);
    if (normalizedValue.isEmpty) {
      return false;
    }
    return _confirmedWarningRawByKey[_readingKey(instrumentCode, parameter)] ==
        normalizedValue;
  }

  String _labelForParameter(String? parameter) {
    final normalized = (parameter ?? '').trim().toUpperCase();
    switch (normalized) {
      case 'LECTURA_CR10X':
        return 'Lectura';
      case 'LECTURA_LU':
        return 'Lectura LU';
      case 'TEMPERATURA':
        return 'Temperatura';
      case 'PERIODO_X':
        return 'Eje X';
      case 'PERIODO_Y':
        return 'Eje Y';
      case 'PERIODO_Z':
        return 'Eje Z';
      default:
        return normalized.isEmpty ? 'Lectura' : normalized;
    }
  }

  String? _buildReadingNotes({
    required bool warningConfirmed,
    String? existingNotes,
  }) {
    final cleanedExisting = existingNotes?.trim();
    if (!warningConfirmed) {
      if (cleanedExisting == null || cleanedExisting.isEmpty) {
        return null;
      }
      if (cleanedExisting == _confirmedOutOfRangeNote) {
        return null;
      }
      return cleanedExisting;
    }

    if (cleanedExisting == null || cleanedExisting.isEmpty) {
      return _confirmedOutOfRangeNote;
    }
    if (cleanedExisting.contains(_confirmedOutOfRangeNote)) {
      return cleanedExisting;
    }
    return '$cleanedExisting | $_confirmedOutOfRangeNote';
  }

  List<OutOfRangeReviewItem> _pendingOutOfRangeReviewItems(
    List<Instrumento> instrumentos,
  ) {
    if (_currentPlanilla == null) {
      return const [];
    }

    final pending = <OutOfRangeReviewItem>[];

    for (final lectura in _currentPlanilla!.lecturas) {
      if (lectura.fueraDeRango != true ||
          lectura.advertenciaConfirmada == true) {
        continue;
      }
      if (lectura.value == null ||
          lectura.rangoMin == null ||
          lectura.rangoMax == null ||
          lectura.valorRaw == null) {
        continue;
      }

      pending.add(
        OutOfRangeReviewItem(
          readingKey: _readingKey(lectura.instrumentCode, lectura.parameter),
          instrumentCode: lectura.instrumentCode,
          label: _labelForParameter(lectura.parameter),
          rawValue: lectura.valorRaw!,
          value: lectura.value!,
          min: lectura.rangoMin!,
          max: lectura.rangoMax!,
        ),
      );
    }

    return pending;
  }

  Future<bool> _ensureOutOfRangeConfirmation(
    List<Instrumento> instrumentos,
  ) async {
    if (_currentPlanilla == null) {
      return false;
    }

    _syncPlanillaFromInputs(instrumentos);
    final pendingItems = _pendingOutOfRangeReviewItems(instrumentos);
    if (pendingItems.isEmpty) {
      setState(() => _reviewHighlightedKeys.clear());
      return true;
    }

    final confirmed = await showOutOfRangeReviewSheet(
      context,
      items: pendingItems,
    );
    if (confirmed != true) {
      if (!mounted) return false;
      setState(() {
        _reviewHighlightedKeys
          ..clear()
          ..addAll(pendingItems.map((item) => item.readingKey));
      });
      return false;
    }

    setState(() {
      _reviewHighlightedKeys.clear();
      for (final item in pendingItems) {
        _confirmedWarningRawByKey[item.readingKey] = item.rawValue;
      }
    });

    _syncPlanillaFromInputs(instrumentos);
    return true;
  }

  bool _controllerHasInvalidValue(TextEditingController controller) {
    return Lectura.isInvalidRawValue(controller.text);
  }

  bool get _hasInvalidInputs =>
      _controllers.values.any(_controllerHasInvalidValue);

  void _showInvalidValuesMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Hay valores con formato incorrecto. RevisÃ¡ el formato antes de guardar o enviar.',
        ),
        backgroundColor: Color(0xFFEF4444),
      ),
    );
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
    final iconBgColor = color.withValues(alpha: 0.15);

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

Color _statusBorderColor({
  required bool isInvalid,
  required bool isOutOfRange,
  required bool isWithinRange,
  bool needsReviewHighlight = false,
}) {
  if (isInvalid) return const Color(0xFFEF4444);
  if (isOutOfRange) return const Color(0xFFF59E0B);
  if (isWithinRange) return const Color(0xFF22C55E);
  if (needsReviewHighlight) return const Color(0xFFF59E0B);
  return const Color(0xFF334155);
}

Color _statusBackgroundColor({
  required bool isInvalid,
  required bool isOutOfRange,
  required bool isWithinRange,
}) {
  if (isInvalid) return const Color(0xFF3F1D1D);
  if (isOutOfRange) return const Color(0xFF422006);
  if (isWithinRange) return const Color(0xFF13261B);
  return const Color(0xFF1E293B);
}

Color _statusFieldFillColor({
  required bool isInvalid,
  required bool isOutOfRange,
  required bool isWithinRange,
  bool needsReviewHighlight = false,
}) {
  if (isInvalid) return const Color(0xFF451A1A);
  if (isOutOfRange) return const Color(0xFF78350F);
  if (isWithinRange) return const Color(0xFF12301F);
  if (needsReviewHighlight) return const Color(0xFF2C1E0A);
  return const Color(0xFF0F172A);
}

Color _statusHelperColor({
  required bool isInvalid,
  required bool isOutOfRange,
  required bool isWithinRange,
}) {
  if (isInvalid) return const Color(0xFFFCA5A5);
  if (isOutOfRange) return const Color(0xFFFBBF24);
  if (isWithinRange) return const Color(0xFF86EFAC);
  return Colors.grey[500]!;
}

String _statusHelperText({
  required bool isInvalid,
  required bool isOutOfRange,
  required bool isWithinRange,
  required bool hasRange,
  required InstrumentRange? range,
  String? labelPrefix,
}) {
  final prefix = labelPrefix == null ? '' : '$labelPrefix | ';
  if (isInvalid) {
    return '${prefix}Formato incorrecto | $decimalInputFormatHelp';
  }
  if (isOutOfRange && range != null) {
    return '${prefix}Fuera de rango | Esperado: ${range.fullLabel}';
  }
  if (isWithinRange && range != null) {
    return '${prefix}Dentro del rango esperado (${range.fullLabel})';
  }
  if (!hasRange) {
    return '${prefix}Sin referencia historica';
  }
  if (range != null) {
    return '${prefix}Esperado: ${range.fullLabel}';
  }
  return '${prefix}Sin referencia historica';
}

class _InstrumentInputRow extends StatefulWidget {
  final Instrumento instrumento;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final String unitLabel;
  final Function(String) onSave;
  final InstrumentRange? range;
  final bool isWarningConfirmed;
  final bool needsReviewHighlight;

  const _InstrumentInputRow({
    required this.instrumento,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.unitLabel,
    required this.onSave,
    this.range,
    this.isWarningConfirmed = false,
    this.needsReviewHighlight = false,
  });

  @override
  State<_InstrumentInputRow> createState() => _InstrumentInputRowState();
}

class _InstrumentInputRowState extends State<_InstrumentInputRow> {
  bool _isOutOfRange = false;
  bool _isInvalidValue = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_checkRange);
    _checkRange();
  }

  @override
  void didUpdateWidget(covariant _InstrumentInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_checkRange);
      widget.controller.addListener(_checkRange);
    }
    _checkRange();
  }

  void _checkRange() {
    final rawValue = widget.controller.text;
    final invalid = Lectura.isInvalidRawValue(rawValue);
    final parsedValue = Lectura.parseRawValue(rawValue);
    final outOfRange = parsedValue != null &&
        widget.range != null &&
        widget.range!.hasRange &&
        widget.range!.isOutOfRange(parsedValue);
    if (outOfRange != _isOutOfRange || invalid != _isInvalidValue) {
      setState(() {
        _isOutOfRange = outOfRange;
        _isInvalidValue = invalid;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkRange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRange = widget.range?.hasRange == true;
    final hasTypedValue = widget.controller.text.trim().isNotEmpty;
    final isWithinRange =
        hasTypedValue && hasRange && !_isOutOfRange && !_isInvalidValue;
    final borderColor = _statusBorderColor(
      isInvalid: _isInvalidValue,
      isOutOfRange: _isOutOfRange,
      isWithinRange: isWithinRange,
      needsReviewHighlight: widget.needsReviewHighlight,
    );
    final backgroundColor = _statusBackgroundColor(
      isInvalid: _isInvalidValue,
      isOutOfRange: _isOutOfRange,
      isWithinRange: isWithinRange,
    );
    final helperText = _statusHelperText(
      isInvalid: _isInvalidValue,
      isOutOfRange: _isOutOfRange,
      isWithinRange: isWithinRange,
      hasRange: hasRange,
      range: widget.range,
    );
    final helperColor = _statusHelperColor(
      isInvalid: _isInvalidValue,
      isOutOfRange: _isOutOfRange,
      isWithinRange: isWithinRange,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  widget.instrumento.codigo,
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
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => widget.onSubmitted(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.grey[700]),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: _statusFieldFillColor(
                      isInvalid: _isInvalidValue,
                      isOutOfRange: _isOutOfRange,
                      isWithinRange: isWithinRange,
                      needsReviewHighlight: widget.needsReviewHighlight,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  widget.unitLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save_as_outlined,
                    color: Color(0xFF3B82F6), size: 20),
                onPressed: () => widget.onSave(widget.controller.text),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                tooltip: 'Guardar valor',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 78),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  helperText,
                  style: TextStyle(
                    fontSize: 10,
                    color: helperColor,
                    fontWeight: isWithinRange || _isOutOfRange
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (_isOutOfRange && widget.isWarningConfirmed)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Confirmado en campo',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFFDE68A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (widget.needsReviewHighlight)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Revisa este valor antes de continuar',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AsentimetroInputRow extends StatefulWidget {
  final Instrumento instrumento;
  final TextEditingController luController;
  final TextEditingController tempController;
  final FocusNode luFocusNode;
  final FocusNode tempFocusNode;
  final VoidCallback onPrimarySubmitted;
  final VoidCallback onTempSubmitted;
  final void Function(String luValue, String tempValue) onSave;
  final InstrumentRange? rangeLu;
  final InstrumentRange? rangeTemp;
  final bool isLuWarningConfirmed;
  final bool isTempWarningConfirmed;
  final bool needsReviewLu;
  final bool needsReviewTemp;

  const _AsentimetroInputRow({
    required this.instrumento,
    required this.luController,
    required this.tempController,
    required this.luFocusNode,
    required this.tempFocusNode,
    required this.onPrimarySubmitted,
    required this.onTempSubmitted,
    required this.onSave,
    this.rangeLu,
    this.rangeTemp,
    this.isLuWarningConfirmed = false,
    this.isTempWarningConfirmed = false,
    this.needsReviewLu = false,
    this.needsReviewTemp = false,
  });

  @override
  State<_AsentimetroInputRow> createState() => _AsentimetroInputRowState();
}

class _AsentimetroInputRowState extends State<_AsentimetroInputRow> {
  bool _isLuOutOfRange = false;
  bool _isTempOutOfRange = false;
  bool _isLuInvalid = false;
  bool _isTempInvalid = false;

  @override
  void initState() {
    super.initState();
    widget.luController.addListener(_validateLuRange);
    widget.tempController.addListener(_validateTempRange);
    _validateLuRange();
    _validateTempRange();
  }

  @override
  void didUpdateWidget(covariant _AsentimetroInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.luController != widget.luController) {
      oldWidget.luController.removeListener(_validateLuRange);
      widget.luController.addListener(_validateLuRange);
    }
    if (oldWidget.tempController != widget.tempController) {
      oldWidget.tempController.removeListener(_validateTempRange);
      widget.tempController.addListener(_validateTempRange);
    }
    _validateLuRange();
    _validateTempRange();
  }

  @override
  void dispose() {
    widget.luController.removeListener(_validateLuRange);
    widget.tempController.removeListener(_validateTempRange);
    super.dispose();
  }

  void _validateLuRange() {
    final rawValue = widget.luController.text;
    final invalid = Lectura.isInvalidRawValue(rawValue);
    final parsedValue = Lectura.parseRawValue(rawValue);
    final outOfRange = parsedValue != null &&
        widget.rangeLu != null &&
        widget.rangeLu!.hasRange &&
        widget.rangeLu!.isOutOfRange(parsedValue);
    if (_isLuOutOfRange != outOfRange || _isLuInvalid != invalid) {
      setState(() {
        _isLuOutOfRange = outOfRange;
        _isLuInvalid = invalid;
      });
    }
  }

  void _validateTempRange() {
    final rawValue = widget.tempController.text;
    final invalid = Lectura.isInvalidRawValue(rawValue);
    final parsedValue = Lectura.parseRawValue(rawValue);
    final outOfRange = parsedValue != null &&
        widget.rangeTemp != null &&
        widget.rangeTemp!.hasRange &&
        widget.rangeTemp!.isOutOfRange(parsedValue);
    if (_isTempOutOfRange != outOfRange || _isTempInvalid != invalid) {
      setState(() {
        _isTempOutOfRange = outOfRange;
        _isTempInvalid = invalid;
      });
    }
  }

  Widget _buildStatusLine({
    required String label,
    required bool isInvalid,
    required bool isOutOfRange,
    required bool isWithinRange,
    required bool hasRange,
    required InstrumentRange? range,
    required bool isWarningConfirmed,
    required bool needsReviewHighlight,
  }) {
    final helperText = _statusHelperText(
      isInvalid: isInvalid,
      isOutOfRange: isOutOfRange,
      isWithinRange: isWithinRange,
      hasRange: hasRange,
      range: range,
      labelPrefix: label,
    );
    final helperColor = _statusHelperColor(
      isInvalid: isInvalid,
      isOutOfRange: isOutOfRange,
      isWithinRange: isWithinRange,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            helperText,
            style: TextStyle(
              fontSize: 9,
              color: helperColor,
              fontWeight: isWithinRange || isOutOfRange
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
          if (isOutOfRange && isWarningConfirmed)
            Text(
              '$label | Confirmado en campo',
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFFDE68A),
                fontWeight: FontWeight.w600,
              ),
            ),
          if (needsReviewHighlight)
            Text(
              '$label | Revisa este valor antes de continuar',
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFFBBF24),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLuRange = widget.rangeLu?.hasRange == true;
    final hasTempRange = widget.rangeTemp?.hasRange == true;
    final hasLuValue = widget.luController.text.trim().isNotEmpty;
    final hasTempValue = widget.tempController.text.trim().isNotEmpty;
    final isLuWithinRange =
        hasLuValue && hasLuRange && !_isLuOutOfRange && !_isLuInvalid;
    final isTempWithinRange =
        hasTempValue && hasTempRange && !_isTempOutOfRange && !_isTempInvalid;
    final anyOutOfRange = _isLuOutOfRange || _isTempOutOfRange;
    final anyInvalid = _isLuInvalid || _isTempInvalid;
    final anyWithinRange = isLuWithinRange || isTempWithinRange;
    final needsReviewHighlight = widget.needsReviewLu || widget.needsReviewTemp;
    final borderColor = _statusBorderColor(
      isInvalid: anyInvalid,
      isOutOfRange: anyOutOfRange,
      isWithinRange: anyWithinRange,
      needsReviewHighlight: needsReviewHighlight,
    );
    final backgroundColor = _statusBackgroundColor(
      isInvalid: anyInvalid,
      isOutOfRange: anyOutOfRange,
      isWithinRange: anyWithinRange,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  widget.instrumento.codigo,
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
                  controller: widget.luController,
                  focusNode: widget.luFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => widget.onPrimarySubmitted(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'LU',
                    hintStyle: TextStyle(color: Colors.grey[700]),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: _statusFieldFillColor(
                      isInvalid: _isLuInvalid,
                      isOutOfRange: _isLuOutOfRange,
                      isWithinRange: isLuWithinRange,
                      needsReviewHighlight: widget.needsReviewLu,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _statusBorderColor(
                          isInvalid: _isLuInvalid,
                          isOutOfRange: _isLuOutOfRange,
                          isWithinRange: isLuWithinRange,
                          needsReviewHighlight: widget.needsReviewLu,
                        ),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _statusBorderColor(
                          isInvalid: _isLuInvalid,
                          isOutOfRange: _isLuOutOfRange,
                          isWithinRange: isLuWithinRange,
                          needsReviewHighlight: widget.needsReviewLu,
                        ),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _statusBorderColor(
                          isInvalid: _isLuInvalid,
                          isOutOfRange: _isLuOutOfRange,
                          isWithinRange: isLuWithinRange,
                          needsReviewHighlight: widget.needsReviewLu,
                        ),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: widget.tempController,
                  focusNode: widget.tempFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => widget.onTempSubmitted(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'T',
                    hintStyle: TextStyle(color: Colors.grey[700]),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: _statusFieldFillColor(
                      isInvalid: _isTempInvalid,
                      isOutOfRange: _isTempOutOfRange,
                      isWithinRange: isTempWithinRange,
                      needsReviewHighlight: widget.needsReviewTemp,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _statusBorderColor(
                          isInvalid: _isTempInvalid,
                          isOutOfRange: _isTempOutOfRange,
                          isWithinRange: isTempWithinRange,
                          needsReviewHighlight: widget.needsReviewTemp,
                        ),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _statusBorderColor(
                          isInvalid: _isTempInvalid,
                          isOutOfRange: _isTempOutOfRange,
                          isWithinRange: isTempWithinRange,
                          needsReviewHighlight: widget.needsReviewTemp,
                        ),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _statusBorderColor(
                          isInvalid: _isTempInvalid,
                          isOutOfRange: _isTempOutOfRange,
                          isWithinRange: isTempWithinRange,
                          needsReviewHighlight: widget.needsReviewTemp,
                        ),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.save_as_outlined,
                    color: Color(0xFF3B82F6), size: 20),
                onPressed: () => widget.onSave(
                    widget.luController.text, widget.tempController.text),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                tooltip: 'Guardar LU + temperatura',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 70),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusLine(
                  label: 'Lectura LU',
                  isInvalid: _isLuInvalid,
                  isOutOfRange: _isLuOutOfRange,
                  isWithinRange: isLuWithinRange,
                  hasRange: hasLuRange,
                  range: widget.rangeLu,
                  isWarningConfirmed: widget.isLuWarningConfirmed,
                  needsReviewHighlight: widget.needsReviewLu,
                ),
                _buildStatusLine(
                  label: 'Temperatura',
                  isInvalid: _isTempInvalid,
                  isOutOfRange: _isTempOutOfRange,
                  isWithinRange: isTempWithinRange,
                  hasRange: hasTempRange,
                  range: widget.rangeTemp,
                  isWarningConfirmed: widget.isTempWarningConfirmed,
                  needsReviewHighlight: widget.needsReviewTemp,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TriaxialInputRow extends StatelessWidget {
  final String instrumentCode;
  final bool hasCatalogReference;
  final TextEditingController controllerX;
  final TextEditingController controllerY;
  final TextEditingController controllerZ;
  final FocusNode focusNodeX;
  final FocusNode focusNodeY;
  final FocusNode focusNodeZ;
  final VoidCallback onXSubmitted;
  final VoidCallback onYSubmitted;
  final VoidCallback onZSubmitted;
  final void Function(String x, String y, String z) onSave;
  final InstrumentRange? rangeX;
  final InstrumentRange? rangeY;
  final InstrumentRange? rangeZ;
  final bool isWarningConfirmedX;
  final bool isWarningConfirmedY;
  final bool isWarningConfirmedZ;
  final bool needsReviewX;
  final bool needsReviewY;
  final bool needsReviewZ;

  const _TriaxialInputRow({
    required this.instrumentCode,
    required this.hasCatalogReference,
    required this.controllerX,
    required this.controllerY,
    required this.controllerZ,
    required this.focusNodeX,
    required this.focusNodeY,
    required this.focusNodeZ,
    required this.onXSubmitted,
    required this.onYSubmitted,
    required this.onZSubmitted,
    required this.onSave,
    this.rangeX,
    this.rangeY,
    this.rangeZ,
    this.isWarningConfirmedX = false,
    this.isWarningConfirmedY = false,
    this.isWarningConfirmedZ = false,
    this.needsReviewX = false,
    this.needsReviewY = false,
    this.needsReviewZ = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                instrumentCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1A14B8A6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x4D14B8A6)),
                ),
                child: const Text(
                  'Ejes X/Y/Z',
                  style: TextStyle(
                    color: Color(0xFF14B8A6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!hasCatalogReference) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF475569)),
                  ),
                  child: const Text(
                    'Sin referencia',
                    style: TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.save_as_outlined,
                    color: Color(0xFF3B82F6), size: 20),
                onPressed: () => onSave(
                    controllerX.text, controllerY.text, controllerZ.text),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                tooltip: 'Guardar X/Y/Z',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TriaxialAxisField(
                  axisLabel: 'X',
                  controller: controllerX,
                  focusNode: focusNodeX,
                  onSubmitted: onXSubmitted,
                  range: rangeX,
                  isWarningConfirmed: isWarningConfirmedX,
                  needsReviewHighlight: needsReviewX,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TriaxialAxisField(
                  axisLabel: 'Y',
                  controller: controllerY,
                  focusNode: focusNodeY,
                  onSubmitted: onYSubmitted,
                  range: rangeY,
                  isWarningConfirmed: isWarningConfirmedY,
                  needsReviewHighlight: needsReviewY,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TriaxialAxisField(
                  axisLabel: 'Z',
                  controller: controllerZ,
                  focusNode: focusNodeZ,
                  onSubmitted: onZSubmitted,
                  range: rangeZ,
                  isWarningConfirmed: isWarningConfirmedZ,
                  needsReviewHighlight: needsReviewZ,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TriaxialAxisField extends StatefulWidget {
  final String axisLabel;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final InstrumentRange? range;
  final bool isWarningConfirmed;
  final bool needsReviewHighlight;

  const _TriaxialAxisField({
    required this.axisLabel,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.range,
    this.isWarningConfirmed = false,
    this.needsReviewHighlight = false,
  });

  @override
  State<_TriaxialAxisField> createState() => _TriaxialAxisFieldState();
}

class _TriaxialAxisFieldState extends State<_TriaxialAxisField> {
  bool _isOutOfRange = false;
  bool _isInvalidValue = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validateRange);
    _validateRange();
  }

  @override
  void didUpdateWidget(covariant _TriaxialAxisField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_validateRange);
      widget.controller.addListener(_validateRange);
    }
    _validateRange();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateRange);
    super.dispose();
  }

  void _validateRange() {
    final rawValue = widget.controller.text;
    final invalid = Lectura.isInvalidRawValue(rawValue);
    final parsedValue = Lectura.parseRawValue(rawValue);
    final outOfRange = parsedValue != null &&
        widget.range != null &&
        widget.range!.hasRange &&
        widget.range!.isOutOfRange(parsedValue);
    if (_isOutOfRange != outOfRange || _isInvalidValue != invalid) {
      setState(() {
        _isOutOfRange = outOfRange;
        _isInvalidValue = invalid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRange = widget.range?.hasRange == true;
    final hasTypedValue = widget.controller.text.trim().isNotEmpty;
    final isWithinRange =
        hasTypedValue && hasRange && !_isOutOfRange && !_isInvalidValue;
    final borderColor = _statusBorderColor(
      isInvalid: _isInvalidValue,
      isOutOfRange: _isOutOfRange,
      isWithinRange: isWithinRange,
      needsReviewHighlight: widget.needsReviewHighlight,
    );
    final helperText = _statusHelperText(
      isInvalid: _isInvalidValue,
      isOutOfRange: _isOutOfRange,
      isWithinRange: isWithinRange,
      hasRange: hasRange,
      range: widget.range,
      labelPrefix: 'Eje ${widget.axisLabel}',
    );
    final helperColor = _statusHelperColor(
      isInvalid: _isInvalidValue,
      isOutOfRange: _isOutOfRange,
      isWithinRange: isWithinRange,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => widget.onSubmitted(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: widget.axisLabel,
            labelStyle: const TextStyle(color: Color(0xFF14B8A6), fontSize: 12),
            hintText: '0.00',
            hintStyle: TextStyle(color: Colors.grey[700]),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: _statusFieldFillColor(
              isInvalid: _isInvalidValue,
              isOutOfRange: _isOutOfRange,
              isWithinRange: isWithinRange,
              needsReviewHighlight: widget.needsReviewHighlight,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor, width: 1.2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                helperText,
                style: TextStyle(
                  fontSize: 9,
                  color: helperColor,
                  fontWeight: isWithinRange || _isOutOfRange
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (_isOutOfRange && widget.isWarningConfirmed)
                const Text(
                  'Confirmado en campo',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFFFDE68A),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              if (widget.needsReviewHighlight)
                const Text(
                  'Revisa este valor antes de continuar',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFFFBBF24),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
