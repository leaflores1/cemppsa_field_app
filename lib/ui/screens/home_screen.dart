import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../repositories/planillas_repository.dart';
import '../../services/offline_storage.dart';
import 'form_screen.dart';
import 'planillas_hub_screen.dart';
import 'ingest_hub_screen.dart';
import '../widgets/connectivity_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();

    Future<void> _crearPlanillaFlow() async {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => const _NuevaPlanillaDialog(),
      );

      if (result == null) return;

      final newId = context.read<PlanillasRepository>().createDraft(
            tipoMedicion: result['instrumento']!,
            tecnico: result['tecnico']!,
          );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FormScreen(planillaId: newId)),
      );
    }

    return Scaffold(
      // background lo pone el Theme
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Image.asset(
            'assets/images/cemppsa_logo.png',
            height: 58,
            fit: BoxFit.contain,
          ),
        ),
      ),

      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: Stack(
          children: [
            // “Esferas” sutiles como en la web
            Positioned(
              top: -140,
              right: -120,
              child: _GlowBlob(size: 420, opacity: 0.22),
            ),
            Positioned(
              bottom: -160,
              left: -130,
              child: _GlowBlob(size: 360, opacity: 0.18),
            ),

            // contenido
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroHeader(
                    title: 'Consola de Auscultación',
                    subtitle:
                        'Cargá planillas offline, validá lecturas y sincronizá cuando haya conexión.',
                  ),
                  const SizedBox(height: 14),

                  _GlassCard(
                    title: 'Mis planillas',
                    subtitle: 'Accedé a tus planillas guardadas, enviadas o en progreso.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ConnectivityBanner(),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusPill(
                              label: 'Borradores',
                              value: repo.countDrafts,
                              tone: _PillTone.neutral,
                            ),
                            _StatusPill(
                              label: 'Enviando',
                              value: repo.countSending,
                              tone: _PillTone.warn,
                            ),
                            _StatusPill(
                              label: 'Enviadas',
                              value: repo.countSent,
                              tone: _PillTone.good,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _crearPlanillaFlow,
                          icon: const Icon(Icons.add),
                          label: const Text('Crear planilla'),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PlanillasHubScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  _GlassCard(
                    title: 'Enviar desde otra fuente',
                    subtitle: 'Exportá o enviá datos manualmente: CSV, fotos o email.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _QuickButton(
                          icon: Icons.upload_file,
                          label: 'Exportar CSV',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const IngestHubScreen()),
                          ),
                        ),
                        _QuickButton(
                          icon: Icons.camera_alt,
                          label: 'Subir captura',
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Función "Subir captura" próximamente')),
                          ),
                        ),
                        _QuickButton(
                          icon: Icons.email,
                          label: 'Enviar por mail',
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Función "Enviar por mail" próximamente')),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const IngestHubScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Tip: trabajás offline sin miedo. Cuando vuelve la red, sincronizás.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.55),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btn1",
            onPressed: _crearPlanillaFlow,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "btn2",
            backgroundColor: const Color(0xFFFF6B6B),
            tooltip: 'Limpiar outbox (cola offline)',
            onPressed: () async {
              final offline = context.read<OfflineStorage>();
              await offline.clear();
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Outbox limpiado ✅')),
              );
            },
            child: const Icon(Icons.delete_forever),
          ),
        ],
      ),
    );
  }
}

// ---------- UI helpers ----------

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeroHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleLarge),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: t.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.70)),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onTap;

  const _GlassCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: t.bodySmall?.copyWith(color: Colors.white.withOpacity(0.62)),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

enum _PillTone { neutral, warn, good }

class _StatusPill extends StatelessWidget {
  final String label;
  final int value;
  final _PillTone tone;

  const _StatusPill({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final (Color dot, Color border) = switch (tone) {
      _PillTone.good => (const Color(0xFF34D399), const Color(0x5534D399)),
      _PillTone.warn => (const Color(0xFFFBBF24), const Color(0x55FBBF24)),
      _PillTone.neutral => (const Color(0xFF94A3B8), const Color(0x5594A3B8)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final double opacity;
  const _GlowBlob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF7DE3F7).withOpacity(opacity),
            const Color(0xFF9FB7FF).withOpacity(opacity * 0.55),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

// ---------- Diálogo de nueva planilla ----------

class _NuevaPlanillaDialog extends StatefulWidget {
  const _NuevaPlanillaDialog();

  @override
  State<_NuevaPlanillaDialog> createState() => _NuevaPlanillaDialogState();
}

class _NuevaPlanillaDialogState extends State<_NuevaPlanillaDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _instrumento;
  final _tecnicoCtrl = TextEditingController();

  final _instrumentos = const [
    'Piezómetros',
    'Freatímetro',
    'Acelerómetro',
    'Aforadores',
    'Caudalímetro',
  ];

  @override
  void dispose() {
    _tecnicoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1A2B),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: Theme.of(context).textTheme.titleMedium,
      contentTextStyle: Theme.of(context).textTheme.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Nueva Planilla'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Instrumento'),
              dropdownColor: const Color(0xFF0F1A2B),
              items: _instrumentos
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              value: _instrumento,
              onChanged: (v) => setState(() => _instrumento = v),
              validator: (v) => v == null ? 'Seleccione un instrumento' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _tecnicoCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del técnico'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(0.75))),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'instrumento': _instrumento!,
              'tecnico': _tecnicoCtrl.text.trim(),
            });
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
