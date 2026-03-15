import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class OfflineUnlockScreen extends StatefulWidget {
  const OfflineUnlockScreen({super.key});

  @override
  State<OfflineUnlockScreen> createState() => _OfflineUnlockScreenState();
}

class _OfflineUnlockScreenState extends State<OfflineUnlockScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _obscurePin = true;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final ok = await context.read<AuthService>().unlockWithPin(
          _pinController.text,
        );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isSubmitting = false;
        _error = 'PIN incorrecto. Probá nuevamente.';
      });
      return;
    }

    setState(() {
      _isSubmitting = false;
      _pinController.clear();
    });
  }

  Future<void> _changeAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Cambiar de cuenta',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Esto cerrará la sesión local guardada en este dispositivo y vas a necesitar red para volver a ingresar.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (_, auth, __) {
        final user = auth.currentUser;
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF172554),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Desbloqueo local',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'La app puede seguir trabajando offline con la sesión guardada en este dispositivo.',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _InfoRow(
                            label: 'Operador',
                            value: user?.displayName ?? 'Sesión local',
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: 'Cuenta',
                            value: user?.email ?? '-',
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _pinController,
                            autofocus: true,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'PIN offline',
                              hintText: '4 a 8 dígitos',
                              errorText: _error,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePin = !_obscurePin;
                                  });
                                },
                                icon: Icon(
                                  _obscurePin
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final normalized = (value ?? '').trim();
                              if (!RegExp(r'^\d{4,8}$').hasMatch(normalized)) {
                                return 'Ingresá un PIN de 4 a 8 dígitos';
                              }
                              return null;
                            },
                            onChanged: (_) {
                              if (_error != null) {
                                setState(() => _error = null);
                              }
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.lock_open_rounded),
                              label: Text(
                                _isSubmitting ? 'Verificando...' : 'Entrar offline',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _changeAccount,
                              icon: const Icon(Icons.logout_outlined),
                              label: const Text('Usar otra cuenta'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Solo necesitás conexión cuando quieras sincronizar lotes, refrescar catálogo o volver a iniciar sesión con otra cuenta.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
