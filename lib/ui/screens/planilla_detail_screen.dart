// ==============================================================================
// CEMPPSA Field App - PlanillaDetailScreen
// Detalle de una planilla con todas sus lecturas
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/planilla.dart';
import '../../data/models/lectura.dart';
import '../../repositories/planilla_repository.dart';
import '../widgets/estado_chip.dart';

class PlanillaDetailScreen extends StatefulWidget {
  const PlanillaDetailScreen({super.key});

  @override
  State<PlanillaDetailScreen> createState() => _PlanillaDetailScreenState();
}

class _PlanillaDetailScreenState extends State<PlanillaDetailScreen> {
  late Planilla _planilla;
  bool _editable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _planilla = args['planilla'] as Planilla;
      _editable = args['editable'] as bool? ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(_planilla.tipo.displayName),
        elevation: 0,
        actions: [
          if (_editable)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editPlanilla,
              tooltip: 'Editar',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF1E293B),
            onSelected: _handleMenuAction,
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined,
                        color: Colors.grey, size: 20),
                    SizedBox(width: 12),
                    Text('Exportar', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              if (_planilla.estado == PlanillaEstado.borrador)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          color: Color(0xFFEF4444), size: 20),
                      SizedBox(width: 12),
                      Text('Eliminar',
                          style: TextStyle(color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con info de la planilla
          _buildHeader(),

          // Lista de lecturas
          Expanded(
            child:
                _planilla.isEmpty ? _buildEmptyState() : _buildLecturasList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estado y tipo
          Row(
            children: [
              EstadoChip(estado: _planilla.estado),
              const Spacer(),
              Text(
                '${_planilla.totalLecturas} lecturas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // UUID (truncado)
          Row(
            children: [
              Icon(Icons.fingerprint, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                _planilla.batchUuid.substring(0, 8).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fecha de creacion
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                _formatDateTime(_planilla.createdAt),
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rango de fechas de lecturas
          Row(
            children: [
              Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                _planilla.rangoFechas,
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
            ],
          ),

          // Error message si existe
          if (_planilla.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _planilla.errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Sin lecturas',
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLecturasList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _planilla.lecturas.length,
      itemBuilder: (ctx, index) {
        final lectura = _planilla.lecturas[index];
        return _LecturaRow(
          lectura: lectura,
          onEdit: _editable ? () => _editLectura(index) : null,
        );
      },
    );
  }

  Widget _buildBottomBar() {
    if (_planilla.estado == PlanillaEstado.enviada) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_planilla.estado == PlanillaEstado.borrador) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _markAsPending,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                  child: const Text(
                    'Marcar como lista',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (_planilla.estado == PlanillaEstado.error ||
                _planilla.estado == PlanillaEstado.pendiente)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.sync, color: Colors.white),
                  label: const Text(
                    'Ir a sincronizar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _editPlanilla() {
    final tipo = _planilla.tipo;
    final isCr10x = tipo.codigo.startsWith('CR10X');

    final route = isCr10x ? '/cr10x-batch' : '/manual-reading';

    Navigator.pushNamed(
      context,
      route,
      arguments: _planilla,
    ).then((_) {
      // Refresh state if changed?
      setState(() {});
    });
  }

  Future<void> _editLectura(int index) async {
    final planillaRepo = context.read<PlanillaRepository>();
    final lectura = _planilla.lecturas[index];
    final valueController = TextEditingController(
      text: lectura.valorRaw ?? lectura.value?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: lectura.notes ?? '',
    );

    final updated = await showModalBottomSheet<Lectura>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editar ${lectura.instrumentCode}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final normalized =
                            valueController.text.replaceAll(',', '.').trim();
                        final parsed = double.tryParse(normalized);
                        if (parsed == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Valor numerico invalido'),
                            ),
                          );
                          return;
                        }
                        final notes = notesController.text.trim();
                        Navigator.pop(
                          ctx,
                          lectura.copyWith(
                            value: parsed,
                            notes: notes.isEmpty ? null : notes,
                          ),
                        );
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    valueController.dispose();
    notesController.dispose();

    if (updated == null) return;

    _planilla.lecturas[index] = updated;
    if (_planilla.estado != PlanillaEstado.enviada) {
      _planilla.estado = PlanillaEstado.borrador;
    }

    await planillaRepo.save(_planilla);
    if (!mounted) return;
    setState(() {});
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportPlanilla();
        break;
      case 'delete':
        _confirmDelete();
        break;
    }
  }

  void _exportPlanilla() {
    Navigator.pushNamed(
      context,
      '/export',
      arguments: {'planilla': _planilla},
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar planilla?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Esta accion no se puede deshacer.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final repo = context.read<PlanillaRepository>();
              await repo.delete(_planilla.batchUuid);
              if (!mounted || !ctx.mounted) return;
              Navigator.pop(ctx);
              Navigator.pop(context);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Planilla eliminada'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  void _markAsPending() async {
    _planilla.marcarPendiente();
    await context.read<PlanillaRepository>().save(_planilla);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Planilla marcada como lista para enviar'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// Widget de fila de lectura
// =============================================================================

class _LecturaRow extends StatelessWidget {
  final Lectura lectura;
  final VoidCallback? onEdit;

  const _LecturaRow({
    required this.lectura,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          // Codigo de instrumento
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              lectura.instrumentCode,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // Valor y unidad
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lectura.valorRaw ?? lectura.value?.toString() ?? ''} ${lectura.unit ?? ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${lectura.parameter} - ${_formatTime(lectura.measuredAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // Notas indicator
          if (lectura.notes != null && lectura.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: lectura.notes!,
                child: Icon(Icons.notes, size: 18, color: Colors.grey[600]),
              ),
            ),

          // Edit button
          if (onEdit != null)
            IconButton(
              icon:
                  Icon(Icons.edit_outlined, size: 18, color: Colors.grey[500]),
              onPressed: onEdit,
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
