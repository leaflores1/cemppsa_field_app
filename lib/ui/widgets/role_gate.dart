import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../data/models/user.dart';

class RoleGate extends StatelessWidget {
  final Widget child;
  final List<UserRole> allowedRoles;
  final Widget? fallback;

  const RoleGate({
    super.key,
    required this.child,
    this.allowedRoles = const [],
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    if (user == null) {
      return fallback ??
        const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(
            child: Text(
              "Sesión requerida",
              style: TextStyle(color: Colors.white)
            )
          )
        );
    }

    if (allowedRoles.isNotEmpty && !allowedRoles.contains(user.role)) {
       return fallback ??
        Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(title: const Text('Acceso Restringido')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  "No tienes permisos para ver esta pantalla.",
                  style: TextStyle(color: Colors.white)
                ),
                const SizedBox(height: 8),
                Text(
                  "Rol actual: ${user.role.name}",
                  style: TextStyle(color: Colors.grey[500])
                ),
              ],
            ),
          )
        );
    }

    return child;
  }
}
