// ==============================================================================
// CEMPPSA Field App - UpdateDialog
// Diálogo de actualización OTA con barra de progreso
// ==============================================================================

import 'package:flutter/material.dart';
import '../../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppVersion remoteVersion;
  final bool forcedUpdate;

  const UpdateDialog({
    super.key,
    required this.remoteVersion,
    required this.forcedUpdate,
  });

  /// Muestra el diálogo de actualización.
  /// Si [forced] es true, el usuario NO puede cerrarlo.
  static Future<void> show(
      BuildContext context, AppVersion remote, bool forced) {
    return showDialog(
      context: context,
      barrierDismissible: !forced,
      builder: (_) => UpdateDialog(
        remoteVersion: remote,
        forcedUpdate: forced,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forcedUpdate,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFF22C55E)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Actualización v${widget.remoteVersion.version}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de actualización obligatoria
            if (widget.forcedUpdate)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0x33EF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta actualización es obligatoria',
                        style:
                            TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Changelog
            const Text('Cambios:',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Text(
                  widget.remoteVersion.changelog,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),

            // Barra de progreso
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: const Color(0xFF334155),
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF22C55E)),
              ),
              const SizedBox(height: 4),
              Text(
                _progress > 0
                    ? 'Descargando... ${(_progress * 100).toStringAsFixed(0)}%'
                    : 'Iniciando descarga...',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],

            // Error
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style:
                    const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
            ],
          ],
        ),
        actions: _downloading
            ? null
            : [
                if (!widget.forcedUpdate)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Luego'),
                  ),
                ElevatedButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Actualizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                  ),
                ),
              ],
      ),
    );
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    try {
      await UpdateService.downloadAndInstall(
        widget.remoteVersion,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Error: $e';
        });
      }
    }
  }
}
