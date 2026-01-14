// ==============================================================================
// CEMPPSA Field App - ManualReadingScreen
// Pantalla de lecturas manuales (Casagrande, Freatímetros, Aforadores)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/instrumento.dart';
import '../../data/models/lectura.dart';
import '../../data/models/planilla.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/planilla_repository.dart';
import '../../services/sync_service.dart';
import '../../core/config.dart';

class ManualReadingScreen extends StatefulWidget {
  const ManualReadingScreen({super.key});

  @override
  State<ManualReadingScreen> createState() => _ManualReadingScreenState();
}

class _ManualReadingScreenState extends State<ManualReadingScreen> {
  TipoPlanilla? _selectedTipo;
  Planilla? _currentPlanilla;

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
          if (_currentPlanilla != null && _currentPlanilla!.lecturas.isNotEmpty)
            TextButton.icon(
              onPressed: _saveDraft,
              icon: const Icon(Icons.save_outlined, color: Colors.white70),
              label: const Text('Guardar', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: _selectedTipo == null
          ? _buildTipoSelector()
          : _buildReadingForm(),
    );
  }

  // ===========================================================================
  // Selector de tipo de planilla
  // ===========================================================================

  Widget _buildTipoSelector() {
    final catalog = context.watch<CatalogRepository>();
    
    // Contar instrumentos por tipo
    final casagrandeCount = catalog.all().where((i) =>
        i.familia == FamiliaInstrumento.piezometro &&
        i.subfamilia == Subfamilia.casagrande).length;
    final freatimetrosCount = catalog.byFamilia(FamiliaInstrumento.freatimetro).length;
    final aforadoresCount = catalog.byFamilia(FamiliaInstrumento.aforador).length;
    
    final totalCount = casagrandeCount + freatimetrosCount + aforadoresCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de advertencia si no hay instrumentos
          if (totalCount == 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x1AEF4444),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x4DEF4444)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catálogo vacío',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No hay instrumentos cargados. Verificá la conexión al backend y sincronizá el catálogo desde Configuración.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                icon: const Icon(Icons.settings, color: Colors.white),
                label: const Text('Ir a Configuración'),
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Text(
            '¿Qué tipo de lectura?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Casagrande
          _TipoCard(
            title: 'Piezómetros Casagrande',
            subtitle: 'Lecturas manuales en caseta de compuertas',
            icon: Icons.speed_rounded,
            color: const Color(0xFF3B82F6),
            count: casagrandeCount,
            enabled: casagrandeCount > 0,
            onTap: casagrandeCount > 0 
                ? () => _selectTipo(TipoPlanilla.casagrande)
                : null,
          ),
          const SizedBox(height: 12),

          // Freatímetros
          _TipoCard(
            title: 'Freatímetros',
            subtitle: 'PP1, PP2, PP3...',
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF06B6D4),
            count: freatimetrosCount,
            enabled: freatimetrosCount > 0,
            onTap: freatimetrosCount > 0 
                ? () => _selectTipo(TipoPlanilla.freatimetros)
                : null,
          ),
          const SizedBox(height: 12),

          // Aforadores
          _TipoCard(
            title: 'Aforadores',
            subtitle: 'Pie de presa, galerías, acueducto',
            icon: Icons.waves_rounded,
            color: const Color(0xFF22C55E),
            count: aforadoresCount,
            enabled: aforadoresCount > 0,
            onTap: aforadoresCount > 0 
                ? () => _selectTipo(TipoPlanilla.aforadores)
                : null,
          ),
        ],
      ),
    );
  }

  void _selectTipo(TipoPlanilla tipo) {
    setState(() {
      _selectedTipo = tipo;
      _currentPlanilla = Planilla(
        tipo: tipo,
        deviceId: AppConfig.deviceId ?? 'unknown',
        technicianId: AppConfig.technicianId ?? 'tecnico',
      );
    });
  }

  // ===========================================================================
  // Formulario de lecturas
  // ===========================================================================

  Widget _buildReadingForm() {
    return Column(
      children: [
        // Header con tipo seleccionado
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(bottom: BorderSide(color: Color(0xFF334155))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentPlanilla?.totalLecturas ?? 0} lecturas',
                style: TextStyle(color: Colors.grey[500]),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: _confirmCancel,
              ),
            ],
          ),
        ),

        // Lista de lecturas o estado vacío
        Expanded(
          child: _currentPlanilla == null || _currentPlanilla!.isEmpty
              ? _buildEmptyState()
              : _buildLecturasList(),
        ),

        // Footer con botón agregar
        _buildFooter(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_box_outlined, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Sin lecturas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tocá el botón + para agregar una lectura',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLecturasList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentPlanilla!.lecturas.length,
      itemBuilder: (ctx, index) {
        final lectura = _currentPlanilla!.lecturas[index];
        return _LecturaCard(
          lectura: lectura,
          onEdit: () => _editLectura(index),
          onDelete: () => _deleteLectura(index),
        );
      },
    );
  }

  Widget _buildFooter() {
    final hasLecturas = _currentPlanilla != null && _currentPlanilla!.lecturas.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón agregar lectura
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddLecturaSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Agregar Lectura',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // Botón finalizar (solo si hay lecturas)
            if (hasLecturas) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _finishAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Finalizar y Guardar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Bottom Sheet para agregar/editar lectura
  // ===========================================================================

  void _showAddLecturaSheet({Lectura? existing, int? editIndex}) {
    final catalog = context.read<CatalogRepository>();
    final instrumentos = _getInstrumentosForTipo(catalog);

    // Verificar que hay instrumentos disponibles
    if (instrumentos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay instrumentos disponibles. Sincronizá el catálogo primero.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LecturaFormSheet(
        instrumentos: instrumentos,
        existing: existing,
        onSave: (lectura) {
          if (editIndex != null) {
            setState(() {
              _currentPlanilla!.lecturas[editIndex] = lectura;
            });
          } else {
            _addLectura(lectura);
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }

  List<Instrumento> _getInstrumentosForTipo(CatalogRepository catalog) {
    switch (_selectedTipo) {

      case TipoPlanilla.casagrande:
        return catalog.all().where((i) =>
            i.familia == FamiliaInstrumento.piezometro &&
            i.subfamilia == Subfamilia.casagrande).toList();

      case TipoPlanilla.freatimetros:
        return catalog.byFamilia(FamiliaInstrumento.freatimetro);
      case TipoPlanilla.aforadores:
        return catalog.byFamilia(FamiliaInstrumento.aforador);
      default:
        return [];
    }
  }

  // ===========================================================================
  // Acciones
  // ===========================================================================

  void _addLectura(Lectura lectura) {
    setState(() {
      _currentPlanilla!.agregarLectura(lectura);
    });
  }

  void _editLectura(int index) {
    final lectura = _currentPlanilla!.lecturas[index];
    _showAddLecturaSheet(existing: lectura, editIndex: index);
  }

  void _deleteLectura(int index) {
    setState(() {
      _currentPlanilla!.lecturas.removeAt(index);
    });
  }

  Future<void> _saveDraft() async {
    if (_currentPlanilla == null) return;
    
    await context.read<PlanillaRepository>().save(_currentPlanilla!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrador guardado'),
          backgroundColor: Color(0xFF3B82F6),
        ),
      );
    }
  }

  Future<void> _finishAndSave() async {
    if (_currentPlanilla == null) return;

    final planillaRepo = context.read<PlanillaRepository>();
    final syncService = context.read<SyncService>();
    final totalLecturas = _currentPlanilla!.totalLecturas;

    _currentPlanilla!.marcarPendiente();
    await planillaRepo.save(_currentPlanilla!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Planilla guardada ($totalLecturas lecturas). Sincronizando...'),
          backgroundColor: const Color(0xFF3B82F6),
        ),
      );
      Navigator.pop(context);
    }

    // Sincronizar automáticamente en background
    final result = await syncService.syncAll(planillaRepo);

    if (mounted && result.sent > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.hasErrors
              ? const Color(0xFFF59E0B)
              : const Color(0xFF22C55E),
        ),
      );
    }
  }

  void _confirmCancel() {
    final hasData = _currentPlanilla != null && _currentPlanilla!.lecturas.isNotEmpty;

    if (!hasData) {
      setState(() {
        _selectedTipo = null;
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
          'Tenés ${_currentPlanilla!.totalLecturas} lecturas sin guardar.',
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
                _currentPlanilla = null;
              });
            },
            child: const Text('Descartar', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widgets auxiliares
// =============================================================================

class _TipoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int count;
  final bool enabled;
  final VoidCallback? onTap;

  const _TipoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.count,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBgColor = Color.fromRGBO(
      color.red,
      color.green,
      color.blue,
      enabled ? 0.15 : 0.05,
    );
    final effectiveColor = enabled ? color : Colors.grey[700]!;

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
            border: Border.all(
              color: enabled ? const Color(0xFF334155) : const Color(0xFF1E293B),
            ),
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
                child: Icon(icon, color: effectiveColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: enabled ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? Colors.grey[500] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: enabled 
                          ? Color.fromRGBO(color.red, color.green, color.blue, 0.2)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: effectiveColor,
                      ),
                    ),
                  ),
                  if (!enabled) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sin datos',
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right, 
                color: enabled ? Colors.grey[600] : Colors.grey[800],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LecturaCard extends StatelessWidget {
  final Lectura lectura;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LecturaCard({
    required this.lectura,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          // Código de instrumento
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x1A3B82F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              lectura.instrumentCode,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Valor y metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lectura.value} ${lectura.unit}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatTime(lectura.measuredAt)}${lectura.notes != null && lectura.notes!.isNotEmpty ? ' • ${lectura.notes}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Acciones
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: Colors.grey[500],
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: const Color(0xFFEF4444),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _LecturaFormSheet extends StatefulWidget {
  final List<Instrumento> instrumentos;
  final Lectura? existing;
  final void Function(Lectura) onSave;

  const _LecturaFormSheet({
    required this.instrumentos,
    required this.onSave,
    this.existing,
  });

  @override
  State<_LecturaFormSheet> createState() => _LecturaFormSheetState();
}

class _LecturaFormSheetState extends State<_LecturaFormSheet> {
  Instrumento? _selectedInstrumento;
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _measuredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      // Buscar instrumento existente
      _selectedInstrumento = widget.instrumentos.firstWhere(
        (i) => i.codigo == widget.existing!.instrumentCode,
        orElse: () => widget.instrumentos.first,
      );
      _valueController.text = widget.existing!.value.toString();
      _notesController.text = widget.existing!.notes ?? '';
      _measuredAt = widget.existing!.measuredAt;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          Text(
            widget.existing != null ? 'Editar Lectura' : 'Nueva Lectura',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Selector de instrumento
          const Text(
            'Instrumento',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Instrumento>(
                value: _selectedInstrumento,
                hint: const Text('Seleccionar', style: TextStyle(color: Colors.grey)),
                isExpanded: true,
                dropdownColor: const Color(0xFF1E293B),
                items: widget.instrumentos.map((inst) {
                  return DropdownMenuItem(
                    value: inst,
                    child: Text(
                      '${inst.codigo} - ${inst.nombre}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedInstrumento = v),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Valor
          const Text(
            'Valor',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: '0,00',
                    hintStyle: TextStyle(color: Colors.grey[700]),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  _selectedInstrumento?.defaultUnit ?? 'm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fecha y hora
          const Text(
            'Fecha y hora',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.grey, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _formatDateTime(_measuredAt),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit, color: Colors.grey, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notas (opcional)
          const Text(
            'Notas (opcional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Observaciones...',
              hintStyle: TextStyle(color: Colors.grey[700]),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Botón guardar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSave() ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                disabledBackgroundColor: const Color(0xFF334155),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                widget.existing != null ? 'Actualizar' : 'Agregar',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  bool _canSave() {
    return _selectedInstrumento != null && _valueController.text.isNotEmpty;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_measuredAt),
      );
      if (time != null) {
        setState(() {
          _measuredAt = DateTime(
            date.year, date.month, date.day, time.hour, time.minute,
          );
        });
      }
    }
  }

  void _save() {
    final lectura = Lectura.fromForm(
      clientRowId: widget.existing?.clientRowId ?? DateTime.now().millisecondsSinceEpoch,
      instrumentCode: _selectedInstrumento!.codigo,
      parameter: _selectedInstrumento!.defaultParameter,
      unit: _selectedInstrumento!.defaultUnit,
      rawValue: _valueController.text,
      measuredAt: _measuredAt,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );
    widget.onSave(lectura);
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
