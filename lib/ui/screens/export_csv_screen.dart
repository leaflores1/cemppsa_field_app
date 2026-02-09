// ==============================================================================
// CEMPPSA Field App - ExportCsvScreen
// Pantalla para exportar planillas a CSV
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/planilla.dart';
import '../../repositories/planilla_repository.dart';
import '../../utils/csv_exporter.dart';

class ExportCsvScreen extends StatefulWidget {
  const ExportCsvScreen({super.key});

  @override
  State<ExportCsvScreen> createState() => _ExportCsvScreenState();
}

class _ExportCsvScreenState extends State<ExportCsvScreen> {
  final Set<String> _selectedIds = {};
  bool _selectAll = false;
  bool _exporting = false;
  String? _lastExportPath;

  @override
  Widget build(BuildContext context) {
    // Verificar si viene con una planilla específica
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final singlePlanilla = args?['planilla'] as Planilla?;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Exportar a CSV'),
        elevation: 0,
      ),
      body: singlePlanilla != null
          ? _buildSingleExport(singlePlanilla)
          : _buildMultipleExport(),
    );
  }

  // ===========================================================================
  // Exportar una sola planilla
  // ===========================================================================

  Widget _buildSingleExport(Planilla planilla) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info de la planilla
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        color: Color(0xFF3B82F6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        planilla.tipo.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.numbers,
                  label: 'Lecturas',
                  value: planilla.totalLecturas.toString(),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Fecha',
                  value: _formatDate(planilla.createdAt),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.fingerprint,
                  label: 'ID',
                  value: planilla.batchUuid.substring(0, 8).toUpperCase(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Preview
          const Text(
            'Vista previa',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Text(
                    _generatePreview(planilla),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Botón exportar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exporting ? null : () => _exportSingle(planilla),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.file_download, color: Colors.white),
              label: Text(
                _exporting ? 'Exportando...' : 'Exportar CSV',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Último archivo exportado
          if (_lastExportPath != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF22C55E), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Archivo exportado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                        Text(
                          _lastExportPath!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  // ===========================================================================
  // Exportar múltiples planillas
  // ===========================================================================

  Widget _buildMultipleExport() {
    return Consumer<PlanillaRepository>(
      builder: (context, repo, _) {
        final planillas = repo.all();

        if (planillas.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: [
            // Header con seleccionar todo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (v) => _toggleSelectAll(planillas),
                    activeColor: const Color(0xFF3B82F6),
                  ),
                  Text(
                    'Seleccionar todo (${planillas.length})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedIds.length} seleccionadas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de planillas
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: planillas.length,
                itemBuilder: (ctx, index) {
                  final planilla = planillas[index];
                  final isSelected = _selectedIds.contains(planilla.batchUuid);

                  return _SelectablePlanillaRow(
                    planilla: planilla,
                    isSelected: isSelected,
                    onToggle: () => _toggleSelection(planilla.batchUuid),
                  );
                },
              ),
            ),

            // Footer con botón exportar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(top: BorderSide(color: Color(0xFF334155))),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedIds.isEmpty || _exporting
                        ? null
                        : () => _exportMultiple(planillas),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      disabledBackgroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _exporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.file_download, color: Colors.white),
                    label: Text(
                      _exporting
                          ? 'Exportando...'
                          : 'Exportar ${_selectedIds.length} planilla${_selectedIds.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Sin planillas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Creá planillas para poder exportarlas',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Acciones
  // ===========================================================================

  void _toggleSelectAll(List<Planilla> planillas) {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedIds.addAll(planillas.map((p) => p.batchUuid));
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _selectAll = false;
    });
  }

  Future<void> _exportSingle(Planilla planilla) async {
    setState(() => _exporting = true);

    try {
      final path = await CsvExporter.exportPlanilla(planilla);
      setState(() {
        _lastExportPath = path;
        _exporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV exportado correctamente'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _exportMultiple(List<Planilla> planillas) async {
    final selected =
        planillas.where((p) => _selectedIds.contains(p.batchUuid)).toList();

    setState(() => _exporting = true);

    try {
      final path = await CsvExporter.exportMultiple(selected);
      setState(() {
        _exporting = false;
        _lastExportPath = path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length} planillas exportadas'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _generatePreview(Planilla planilla) {
    final buffer = StringBuffer();
    buffer.writeln('instrument_code,parameter,unit,value,measured_at,notes');

    for (final l in planilla.lecturas.take(5)) {
      buffer.writeln(
        '${l.instrumentCode},${l.parameter},${l.unit},${l.value},'
        '${l.measuredAt.toIso8601String()},${l.notes ?? ""}',
      );
    }

    if (planilla.lecturas.length > 5) {
      buffer.writeln('... (${planilla.lecturas.length - 5} filas más)');
    }

    return buffer.toString();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

// =============================================================================
// Widgets auxiliares
// =============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _SelectablePlanillaRow extends StatelessWidget {
  final Planilla planilla;
  final bool isSelected;
  final VoidCallback onToggle;

  const _SelectablePlanillaRow({
    required this.planilla,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF3B82F6).withOpacity(0.1)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.5)
              : const Color(0xFF334155),
        ),
      ),
      child: ListTile(
        onTap: onToggle,
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) => onToggle(),
          activeColor: const Color(0xFF3B82F6),
        ),
        title: Text(
          planilla.tipo.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          '${planilla.totalLecturas} lecturas',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: Text(
          planilla.batchUuid.substring(0, 6).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
