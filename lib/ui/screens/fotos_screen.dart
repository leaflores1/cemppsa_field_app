import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/foto_inspeccion.dart';
import '../../repositories/foto_repository.dart';
import '../../services/foto_sync_service.dart';

class FotosScreen extends StatefulWidget {
  const FotosScreen({super.key});

  @override
  State<FotosScreen> createState() => _FotosScreenState();
}

class _FotosScreenState extends State<FotosScreen> {
  final _picker = ImagePicker();
  final _loteController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _comentarioController = TextEditingController();

  String _mesOperativo = _defaultMesOperativo();
  String _eventoCodigo = _eventos.first.$1;
  String _eventoNombre = _eventos.first.$2;
  bool _capturando = false;

  static const List<(String, String)> _eventos = [
    ('INSPECCION_VISUAL', 'Inspección Visual'),
    ('MANTENIMIENTO', 'Mantenimiento'),
    ('TORMENTA', 'Tormenta'),
    ('APERTURA_DESCARGADOR', 'Apertura Descargador'),
    ('OTRO', 'Otro'),
  ];

  static String _defaultMesOperativo() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _loteController.dispose();
    _ubicacionController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_capturando) return;
    final fotoRepo = context.read<FotoRepository>();
    final fotoSync = context.read<FotoSyncService>();
    setState(() {
      _capturando = true;
    });

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
      );
      if (picked == null) return;

      final destination = await _persistCapturedFile(picked.path);
      final foto = FotoInspeccion(
        localPath: destination.path,
        mesOperativo: _mesOperativo,
        loteUuid: _loteController.text.trim().isEmpty ? null : _loteController.text.trim(),
        eventoCodigo: _eventoCodigo,
        eventoNombre: _eventoNombre,
        ubicacion: _ubicacionController.text.trim().isEmpty
            ? null
            : _ubicacionController.text.trim(),
        comentario: _comentarioController.text.trim().isEmpty
            ? null
            : _comentarioController.text.trim(),
        takenAt: DateTime.now(),
      );

      await fotoRepo.save(foto);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto guardada localmente como pendiente'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }

      if (mounted && fotoSync.isOnline) {
        await fotoSync.syncPending();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturando foto: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _capturando = false;
        });
      }
    }
  }

  Future<File> _persistCapturedFile(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final fotoDir = Directory(p.join(docsDir.path, 'fotos_locales'));
    if (!fotoDir.existsSync()) {
      fotoDir.createSync(recursive: true);
    }
    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final targetPath = p.join(fotoDir.path, '${const Uuid().v4()}$ext');
    final copied = await File(sourcePath).copy(targetPath);
    return copied;
  }

  Future<void> _syncNow() async {
    final service = context.read<FotoSyncService>();
    await service.syncPending();
    if (!mounted) return;
    final color = service.lastError == null ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final message = service.lastError == null
        ? 'Sincronización de fotos completada'
        : 'Sync parcial: ${service.lastError}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _retryFoto(FotoInspeccion foto) async {
    await context.read<FotoSyncService>().retrySingle(foto.localId);
  }

  Future<void> _deleteFoto(FotoInspeccion foto) async {
    final fotoRepo = context.read<FotoRepository>();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Eliminar foto'),
              content: const Text('¿Eliminar esta foto local? Esta acción no se puede deshacer.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) return;

    try {
      final file = File(foto.localPath);
      if (file.existsSync()) {
        await file.delete();
      }
      await fotoRepo.delete(foto.localId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos / Inspección'),
      ),
      body: SafeArea(
        child: Consumer2<FotoRepository, FotoSyncService>(
          builder: (_, repo, sync, __) {
            final fotos = repo.all();
            return Column(
              children: [
                _buildTopForm(sync),
                const Divider(height: 1),
                Expanded(
                  child: fotos.isEmpty
                      ? const Center(
                          child: Text(
                            'Sin fotos aún.\nTomá una foto para iniciar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: fotos.length,
                          itemBuilder: (_, index) {
                            final foto = fotos[index];
                            return _FotoCard(
                              foto: foto,
                              onRetry: () => _retryFoto(foto),
                              onDelete: () => _deleteFoto(foto),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _capturando ? null : _takePhoto,
        icon: const Icon(Icons.camera_alt_outlined),
        label: Text(_capturando ? 'Abriendo cámara...' : 'Tomar foto'),
      ),
    );
  }

  Widget _buildTopForm(FotoSyncService sync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _mesOperativo,
                  decoration: const InputDecoration(
                    labelText: 'Mes operativo (YYYY-MM)',
                    hintText: '2026-02',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _mesOperativo = value.trim();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _loteController,
                  decoration: const InputDecoration(
                    labelText: 'Lote UUID',
                    hintText: 'opcional',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _eventoCodigo,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Evento'),
                  items: _eventos
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.$1,
                          child: Text(
                            e.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    final tuple = _eventos.firstWhere((item) => item.$1 == value);
                    setState(() {
                      _eventoCodigo = tuple.$1;
                      _eventoNombre = tuple.$2;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ubicacionController,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación / Sección',
                    hintText: 'opcional',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comentarioController,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Comentario',
              hintText: 'detalle de inspección',
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final syncButton = OutlinedButton.icon(
                onPressed: sync.isSyncing ? null : _syncNow,
                icon: sync.isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: const Text('Sincronizar'),
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(
                          label: sync.isOnline ? 'Online' : 'Offline',
                          color: sync.isOnline
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444),
                        ),
                        _StatusChip(
                          label: 'Pendientes ${sync.pendingCount}',
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: syncButton,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  _StatusChip(
                    label: sync.isOnline ? 'Online' : 'Offline',
                    color: sync.isOnline
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: 'Pendientes ${sync.pendingCount}',
                    color: const Color(0xFFF59E0B),
                  ),
                  const Spacer(),
                  syncButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FotoCard extends StatelessWidget {
  final FotoInspeccion foto;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  const _FotoCard({
    required this.foto,
    required this.onRetry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(foto.localPath);
    final status = _statusMeta(foto.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: file.existsSync()
                        ? Image.file(file, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFF0F172A),
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              foto.eventoNombre ?? foto.eventoCodigo ?? 'Sin evento',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          _StatusChip(label: status.$1, color: status.$2),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mes ${foto.mesOperativo} • ${foto.loteUuid ?? 'sin-lote'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        foto.ubicacion ?? 'Sin ubicación',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (foto.comentario != null && foto.comentario!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          foto.comentario!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                      if (foto.lastError != null && foto.lastError!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          foto.lastError!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tomada ${_fmtDate(foto.takenAt)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (foto.status == FotoSyncStatus.error ||
                          foto.status == FotoSyncStatus.pendiente)
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reintentar'),
                        ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static (String, Color) _statusMeta(FotoSyncStatus status) {
    switch (status) {
      case FotoSyncStatus.sincronizada:
        return ('Sincronizada', const Color(0xFF22C55E));
      case FotoSyncStatus.sincronizando:
        return ('Sincronizando', const Color(0xFF3B82F6));
      case FotoSyncStatus.error:
        return ('Error', const Color(0xFFEF4444));
      case FotoSyncStatus.pendiente:
        return ('Pendiente', const Color(0xFFF59E0B));
    }
  }

  static String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
