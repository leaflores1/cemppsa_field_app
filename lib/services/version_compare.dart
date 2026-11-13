// ==============================================================================
// CEMPPSA Field App - Comparación de versiones para actualización OTA
// Funciones puras (sin plataforma) para poder testearlas directamente.
// ==============================================================================

/// Interpreta un número de build que puede venir como int, num o String.
///
/// Cualquier valor ausente, ilegible o negativo se trata como 0: nunca lanza.
int parseBuildNumber(Object? raw) {
  if (raw is int) return raw < 0 ? 0 : raw;
  if (raw is num) {
    if (!raw.isFinite) return 0;
    final value = raw.toInt();
    return value < 0 ? 0 : value;
  }
  if (raw is String) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 0) return 0;
    return value;
  }
  return 0;
}

/// Separa `"X.Y.Z+N"` en la parte semántica y el build opcional.
///
/// Devuelve `build == null` cuando el texto no trae `+N`.
({String version, int? build}) splitVersionAndBuild(String raw) {
  final text = raw.trim();
  final plus = text.indexOf('+');
  if (plus < 0) return (version: text, build: null);
  return (
    version: text.substring(0, plus),
    build: parseBuildNumber(text.substring(plus + 1)),
  );
}

/// Compara dos versiones semánticas `X.Y.Z` (se ignora un sufijo `+N`).
///
/// Retorna negativo si a < b, 0 si a == b, positivo si a > b.
/// Un componente ilegible o ausente vale 0.
int compareSemanticVersions(String a, String b) {
  final partsA = splitVersionAndBuild(a).version.split('.');
  final partsB = splitVersionAndBuild(b).version.split('.');
  for (int i = 0; i < 3; i++) {
    final va = i < partsA.length ? (int.tryParse(partsA[i].trim()) ?? 0) : 0;
    final vb = i < partsB.length ? (int.tryParse(partsB[i].trim()) ?? 0) : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

/// Compara `(versión, build)` contra `(versión, build)`: primero la versión
/// semántica y, si es igual, el número de build.
int compareVersionAndBuild(
  String versionA,
  int buildA,
  String versionB,
  int buildB,
) {
  final semantic = compareSemanticVersions(versionA, versionB);
  if (semantic != 0) return semantic;
  return buildA.compareTo(buildB);
}

/// True si la versión remota debe ofrecerse sobre la instalada.
///
/// Se ofrece cuando la versión remota es mayor, o cuando es igual y el build
/// remoto es mayor que el local. `remoteBuild` y `localBuild` aceptan int o
/// String; ausentes o ilegibles valen 0. Si `remoteBuild` es 0 (un
/// `version.json` viejo sin `build_number`) y `remoteVersion` trae `+N`, se
/// usa ese `N`.
bool isRemoteNewer({
  required String remoteVersion,
  Object? remoteBuild,
  required String localVersion,
  Object? localBuild,
}) {
  var remoteBuildNumber = parseBuildNumber(remoteBuild);
  if (remoteBuildNumber == 0) {
    remoteBuildNumber = splitVersionAndBuild(remoteVersion).build ?? 0;
  }
  return compareVersionAndBuild(
        remoteVersion,
        remoteBuildNumber,
        localVersion,
        parseBuildNumber(localBuild),
      ) >
      0;
}

/// True si la app instalada está por debajo de la versión mínima exigida.
///
/// `minVersion` puede ser `"X.Y.Z"` o `"X.Y.Z+N"`:
/// - Sin `+N` solo cuenta la versión semántica: cualquier build de esa
///   versión (o mayor) cumple el mínimo. Es el comportamiento de siempre y
///   evita forzar a todos los teléfonos que ya tienen esa versión.
/// - Con `+N` se exige además build >= N cuando la versión es la misma.
bool isBelowMinimum({
  required String minVersion,
  required String localVersion,
  Object? localBuild,
}) {
  final minimum = splitVersionAndBuild(minVersion);
  final semantic = compareSemanticVersions(localVersion, minimum.version);
  if (semantic != 0) return semantic < 0;
  final minBuild = minimum.build;
  if (minBuild == null) return false;
  return parseBuildNumber(localBuild) < minBuild;
}
