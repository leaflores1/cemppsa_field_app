import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../repositories/catalogo_repository.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../utils/server_discovery.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isDiscoveringServer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      final lastEmail = auth.lastEmail;
      if (lastEmail != null && lastEmail.trim().isNotEmpty) {
        _emailController.text = lastEmail;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthService>();
    if (!ApiConfig.hasCustomBaseUrl) {
      final foundServer = await _discoverAndApplyServer(showFeedback: true);
      if (!mounted || !foundServer) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No hay servidor configurado. Conectate a la red de la empresa o ingresá la IP manualmente.',
              ),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
        return;
      }
    }

    var ok = await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted || ok) return;

    if (_looksLikeConnectivityIssue(auth.lastError)) {
      ok = await _recoverServerAndRetryLogin(auth);
      if (!mounted || ok) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.lastError ?? 'No se pudo iniciar sesion'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  bool _looksLikeConnectivityIssue(String? error) {
    final value = (error ?? '').toLowerCase();
    if (value.isEmpty) return false;
    return value.contains('timeoutexception') ||
        value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused') ||
        value.contains('network is unreachable') ||
        value.contains('connection timed out');
  }

  Future<bool> _recoverServerAndRetryLogin(AuthService auth) async {
    if (_isDiscoveringServer) return false;

    setState(() => _isDiscoveringServer = true);
    try {
      final found = await _discoverAndApplyServer(showFeedback: true);
      if (!mounted || !found) return false;

      return auth.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } finally {
      if (mounted) {
        setState(() => _isDiscoveringServer = false);
      }
    }
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(
      text: ApiConfig.hasCustomBaseUrl ? ApiConfig.baseUrl : '',
    );
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Servidor', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'URL o IP:puerto',
            hintText: '192.168.100.112:8000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (updated == null) return;

    final normalized = ApiConfig.normalizeBaseUrl(updated);
    if (normalized == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL invalida. Ejemplo: 192.168.100.112:8000'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    await _applyServerUrlChange(normalized, showFeedback: true);
  }

  Future<void> _discoverServer() async {
    setState(() => _isDiscoveringServer = true);

    try {
      final found = await _discoverAndApplyServer(showFeedback: true);
      if (!mounted) return;

      if (!found) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo encontrar el servidor en la red local.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al buscar servidor: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDiscoveringServer = false);
      }
    }
  }

  Future<bool> _discoverAndApplyServer({
    required bool showFeedback,
  }) async {
    final foundUrl = await ServerDiscovery.findServer();
    if (!mounted || foundUrl == null) {
      return false;
    }

    final normalized = ApiConfig.normalizeBaseUrl(foundUrl);
    if (normalized == null) {
      return false;
    }

    await _applyServerUrlChange(normalized, showFeedback: showFeedback);
    return mounted;
  }

  Future<void> _applyServerUrlChange(
    String normalized, {
    required bool showFeedback,
  }) async {
    ApiConfig.setBaseUrl(normalized, markAsCustom: true);
    final settingsBox = await Hive.openBox(StorageConfig.settingsBox);
    await settingsBox.put(ApiConfig.settingsServerUrlKey, normalized);

    if (!mounted) return;

    context.read<AuthService>().updateApiBaseUrl(normalized);
    final sync = context.read<SyncService>();
    sync.updateApiBaseUrl(normalized);
    context.read<CatalogRepository>().setBaseUrl(normalized);
    final connected = await sync.checkConnection();

    if (!mounted) return;

    setState(() {});

    if (!showFeedback) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? 'Servidor actualizado: $normalized'
              : 'Servidor guardado, pero sin conexion al backend',
        ),
        backgroundColor:
            connected ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Consumer<AuthService>(
                builder: (_, auth, __) {
                  return Container(
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
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/favicon.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'CemppsaApp',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Ingresa con tus credenciales habilitadas desde administracion',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: _editServerUrl,
                              icon: const Icon(Icons.dns_outlined, size: 16),
                              label: Text(
                                'Servidor: ${ApiConfig.serverLabel}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Center(
                            child: TextButton.icon(
                              onPressed:
                                  _isDiscoveringServer ? null : _discoverServer,
                              icon: _isDiscoveringServer
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.radar, size: 16),
                              label: Text(
                                _isDiscoveringServer
                                    ? 'Buscando servidor...'
                                    : 'Autodetectar servidor en red',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _isDiscoveringServer
                                      ? Colors.grey
                                      : Colors.blue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'tecnico@cemppsa.com',
                            ),
                            validator: (value) {
                              final input = (value ?? '').trim();
                              if (input.isEmpty) return 'Ingresa tu email';
                              if (!input.contains('@')) return 'Email invalido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Ingresa tu password';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Entrar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
