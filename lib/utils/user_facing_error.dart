String userFacingSyncError(String? rawMessage) {
  final raw = rawMessage?.trim() ?? '';
  if (raw.isEmpty) {
    return 'No se pudo completar la operación. Intentá nuevamente.';
  }

  final lower = raw.toLowerCase();
  if (_containsAny(lower, const [
    'timeout',
    'timed out',
    'socketexception',
    'connection refused',
    'network is unreachable',
    'sin conexión',
    'sin conexion',
  ])) {
    return 'No hay conexión con el servidor. La planilla quedó guardada para reintentar.';
  }

  if (_containsAny(lower, const [
    'sesion vencida',
    'sesión vencida',
    'token expired',
    'invalid token',
    'could not validate credentials',
  ])) {
    return 'La sesión venció. Volvé a iniciar sesión para continuar.';
  }

  if (lower.contains('parametro no permitido') ||
      lower.contains('parámetro no permitido')) {
    final instrument = _extractInstrumentCode(raw);
    final prefix =
        instrument == null ? 'Una lectura' : 'El instrumento $instrument';
    return '$prefix tiene una variable que ya no está habilitada. '
        'Abrí la planilla, revisala y volvé a enviarla.';
  }

  if (lower.contains('statuscode=422') || lower.contains('http 422')) {
    return 'Hay datos de la planilla que el servidor no pudo validar. '
        'Revisá las lecturas marcadas e intentá nuevamente.';
  }

  if (_containsAny(lower, const [
    'mobile platform',
    'no esta habilitado para usar la app',
    'no está habilitado para usar la app',
  ])) {
    return 'El usuario no está habilitado para usar la app móvil.';
  }

  if (_containsAny(lower, const [
    'dispositivo no autorizado',
    'device not authorized',
  ])) {
    return 'El dispositivo no está autorizado para sincronizar.';
  }

  if (_looksTechnical(lower)) {
    return 'No se pudo procesar la planilla en el servidor. '
        'Intentá nuevamente y, si el problema continúa, contactá a soporte.';
  }

  const safePrefixes = [
    'la planilla contiene',
    'la planilla no tiene',
    'planilla manual sin',
    'el usuario no',
    'el dispositivo no',
    'dispositivo no',
    'no hay conexión',
    'sin conexión',
    'la sesión',
  ];
  if (safePrefixes.any(lower.startsWith) && raw.length <= 240) {
    return raw;
  }

  return 'No se pudo completar la operación. Intentá nuevamente y, '
      'si el problema continúa, contactá a soporte.';
}

String userFacingValidationError(dynamic error) {
  if (error is! Map) {
    return 'El servidor no pudo validar esta lectura.';
  }
  final instrument = error['instrument_code']?.toString().trim();
  final message = error['message']?.toString();
  final safe = userFacingSyncError(message);
  if (instrument == null || instrument.isEmpty || safe.contains(instrument)) {
    return safe;
  }
  return '$instrument: $safe';
}

String? _extractInstrumentCode(String raw) {
  final jsonMatch = RegExp(
    r'["\x27]instrument_code["\x27]\s*:\s*["\x27]([A-Za-z0-9_*\-]+)',
    caseSensitive: false,
  ).firstMatch(raw);
  if (jsonMatch != null) return jsonMatch.group(1)?.toUpperCase();

  final plainMatch = RegExp(
    r'instrument_code\s*=\s*([A-Za-z0-9_*\-]+)',
    caseSensitive: false,
  ).firstMatch(raw);
  return plainMatch?.group(1)?.toUpperCase();
}

bool _looksTechnical(String lower) {
  return _containsAny(lower, const [
    'body=',
    'statuscode=',
    'batch_uuid=',
    'traceback',
    'stack trace',
    'sqlexception',
    'sqlalchemy',
    'postgres',
    'psycopg',
    'select ',
    'insert into',
    'update ',
    'delete from',
    'syntax error',
    'constraint failed',
    '{"',
    '[{"',
  ]);
}

bool _containsAny(String value, List<String> needles) =>
    needles.any(value.contains);
