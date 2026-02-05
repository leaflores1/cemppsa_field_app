# Mobile Auth Implementation

## Resumen

Se implementó un sistema completo de autenticación y autorización utilizando JWT (Access + Refresh Token) con persistencia segura y manejo de estado reactivo.

## Arquitectura

- **State Management**: `Provider` (`AuthService`).
- **HTTP Client**: `Dio` con `AuthInterceptor` para manejo automático de tokens y refresh.
- **Storage**: `flutter_secure_storage` para guardar Refresh Token de forma encriptada.

### Estructura de Archivos

- `lib/api/api_client.dart`: Cliente HTTP base (Dio).
- `lib/api/auth_interceptor.dart`: Lógica de inyección de token y refresh automático (401).
- `lib/core/storage/secure_storage_service.dart`: Wrapper para almacenamiento seguro.
- `lib/repositories/auth_repository.dart`: Endpoints de Auth (login, register, me).
- `lib/services/auth_service.dart`: Lógica de negocio y estado (currentUser, loading).
- `lib/ui/screens/auth/`: Pantallas de Login y Registro.
- `lib/ui/widgets/role_gate.dart`: Widget para protección de rutas por rol.

## Flujos

### Login
1. Usuario ingresa credenciales.
2. `AuthRepository` llama a `/auth/login`.
3. Se recibe Access Token + Refresh Token + User.
4. Access Token -> Memoria (`ApiClient`).
5. Refresh Token -> Secure Storage.
6. User -> Memoria (`AuthService`).

### Refresh Token (Automático)
1. `ApiClient` recibe 401 en cualquier request.
2. `AuthInterceptor` intercepta el error.
3. Lee Refresh Token del storage.
4. Llama a `/auth/refresh`.
5. Si exitoso: Actualiza tokens, reintenta request original.
6. Si falla: Borra storage y fuerza Logout.

### Startup (App Launch)
1. `AuthWrapper` en `main.dart` muestra splash.
2. `AuthService.checkAuthStatus()`:
   - Lee refresh token.
   - Si existe, llama a `/auth/refresh` para obtener access token fresco.
   - Llama a `/auth/me` para obtener perfil.
   - Si todo OK -> Home.
   - Si falla -> Login.

## Roles y Permisos

El modelo `User` incluye un enum `UserRole` (user, supervisor, admin).
El widget `RoleGate` permite proteger pantallas:

```dart
RoleGate(
  allowedRoles: [UserRole.admin],
  child: AdminScreen(),
)
```

## Configuración

La URL base y endpoints están en `lib/core/config.dart`.

```dart
static const String loginEndpoint = '/auth/login';
// ...
```

## Mejoras Futuras

- **Biometría**: Usar `local_auth` antes de usar el refresh token almacenado.
- **MFA**: Soportar flujo de challenge en login.
- **Offline**: Permitir acceso limitado solo con metadata guardada si no hay red (actualmente requiere refresh online).
