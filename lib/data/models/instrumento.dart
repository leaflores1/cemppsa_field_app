// ==============================================================================
// CEMPPSA Field App - Modelo Instrumento
// Alineado con: backend Instrumento (familia_instrumento_enum)
// ==============================================================================

/// Familia de instrumento segÃºn el backend
/// Mapea exactamente a: familia_instrumento_enum en MySQL
enum FamiliaInstrumento {
  piezometro('PIEZOMETRO', 'Piezometro'),
  casagrande('CASAGRANDE', 'Casagrande'), // Familia propia
  freatimetro('FREATIMETRO', 'Freatimetro'),
  asentimetro('ASENTIMETRO', 'Asentimetro'),
  aforador('AFORADOR', 'Aforador'),
  celdaPresion('CELDA_PRESION', 'Celda de Presion'),
  triaxial('TRIAXIAL', 'Triaxial'),
  uniaxial('UNIAXIAL', 'Uniaxial'),
  juntaPerimetral('JUNTA_PERIMETRAL', 'Junta Perimetral'),
  termometro('TERMOMETRO', 'Termometro'),
  clinometro('CLINOMETRO', 'Clinometro'),
  limnimetro('LIMNIMETRO', 'Limnimetro'),
  barometro('BAROMETRO', 'Barometro'),
  convergencia('CONVERGENCIA', 'Convergencia'),
  embalse('EMBALSE', 'Embalse'),
  sismos('SISMOS', 'Sismos');

  final String backendValue;
  final String displayName;

  const FamiliaInstrumento(this.backendValue, this.displayName);

  /// Parsea desde el valor del backend
  static FamiliaInstrumento fromBackend(String value) {
    return FamiliaInstrumento.values.firstWhere(
      (f) => f.backendValue == value.toUpperCase(),
      orElse: () => FamiliaInstrumento.piezometro,
    );
  }

  /// Infiere familia a partir del cÃ³digo del instrumento
  static FamiliaInstrumento inferFromCode(String code) {
    final upper = code.toUpperCase();

    // Casagrande (lecturas manuales en cÃ¡mara de compuertas)
    // Solo PC01-PC26 y PC*SEC (con SEC sufijo)
    if (RegExp(r'^PC\d{2}(SEC)?$').hasMatch(upper) &&
        (int.tryParse(upper.substring(2, 4)) ?? 0) <= 26) {
      return FamiliaInstrumento.casagrande;
    }

    // PiezÃ³metros de cuerda vibrante (P + letra de eje)
    // Incluye: PA, PB, PC (solo PC31+), PD, PE, PF, PG
    // PC31, PC41, PC43, PC45, PC48, etc. son piezÃ³metros del Eje C
    if (RegExp(r'^P[ABCDEFG]').hasMatch(upper)) {
      return FamiliaInstrumento.piezometro;
    }

    // FreatÃ­metros
    if (upper.startsWith('PP') ||
        upper.startsWith('D1') ||
        upper.startsWith('D2')) {
      return FamiliaInstrumento.freatimetro;
    }

    // Aforadores
    if (upper.startsWith('AF') ||
        upper.startsWith('ACUE') ||
        upper.startsWith('ALIV') ||
        upper.startsWith('GMD') ||
        upper.startsWith('GSMI') ||
        upper.startsWith('GIMI')) {
      return FamiliaInstrumento.aforador;
    }

    // AsentÃ­metros
    if (upper.startsWith('AD') || upper.startsWith('AE')) {
      return FamiliaInstrumento.asentimetro;
    }

    // Triaxiales (formato: J + nÃºmero + opcional [XYZ])
    // Ejemplos: J1, J2, J1X, J1Y, J1Z, etc.
    if (RegExp(r'^J\d+[XYZ]?$').hasMatch(upper)) {
      return FamiliaInstrumento.triaxial;
    }

    // Uniaxiales
    if (RegExp(r'^U\d+').hasMatch(upper)) {
      return FamiliaInstrumento.uniaxial;
    }

    // ClinÃ³metros (juntas perimetrales)
    if (upper.startsWith('JP')) {
      return FamiliaInstrumento.juntaPerimetral;
    }

    // TermÃ³metros
    if (upper.startsWith('TE') ||
        upper.startsWith('TG') ||
        RegExp(r'^T\d').hasMatch(upper)) {
      return FamiliaInstrumento.termometro;
    }

    // Celdas de presiÃ³n
    if (upper.startsWith('CP') || upper.startsWith('CQ')) {
      return FamiliaInstrumento.celdaPresion;
    }

    // Limnimetro
    if (upper.contains('LIMNI')) {
      return FamiliaInstrumento.limnimetro;
    }

    // BarÃ³metro
    if (upper.contains('BAR') || upper == 'P_BAR') {
      return FamiliaInstrumento.barometro;
    }

    // Default
    return FamiliaInstrumento.piezometro;
  }
}

/// Utilidades para cÃ³digos de instrumento
class CodigoHelper {
  /// Canonicaliza cÃ³digo de instrumento.
  ///
  /// Elimina variantes para formato uniforme:
  /// - PC-05 â†’ PC05
  /// - AE1-41 â†’ AE141
  /// - PP7* â†’ PP7
  static String canonicalize(String codigo) {
    var canonical = codigo.toUpperCase();

    // Remover guiones y asteriscos
    canonical = canonical.replaceAll('-', '').replaceAll('*', '');

    return canonical;
  }

  /// Compara dos cÃ³digos ignorando variantes
  static bool codigoMatch(String codigo1, String codigo2) {
    return canonicalize(codigo1) == canonicalize(codigo2);
  }
}

/// Subfamilias comunes (para clasificaciÃ³n mÃ¡s fina)
/// Corresponde al campo `subfamilia` VARCHAR(50) del backend
class Subfamilia {
  // PiezÃ³metros
  static const String casagrande = 'CASAGRANDE';
  static const String ejeA = 'EJE_A';
  static const String ejeB = 'EJE_B';
  static const String ejeC = 'EJE_C';
  static const String ejeD = 'EJE_D';
  static const String ejeE = 'EJE_E';
  static const String ejeF = 'EJE_F';
  static const String ejeG = 'EJE_G';
  // New: E1 explicitly requested
  static const String ejeE1 = 'EJE_E1';

  // Aforadores
  static const String piePresa = 'PIE_PRESA';
  static const String galeriaMD = 'GMD';
  static const String galeriaMI = 'GMI';
  static const String caverna = 'CAVERNA';
  static const String acueducto = 'ACUEDUCTO';
  static const String aliviadero = 'ALIVIADERO';

  /// Infiere subfamilia desde el cÃ³digo
  static String? inferFromCode(String code) {
    final upper = code.toUpperCase();

    // PiezÃ³metros Casagrande (lectura manual) - Solo PC01-PC26
    if (RegExp(r'^PC\d{2}(SEC)?$').hasMatch(upper) &&
        (int.tryParse(upper.substring(2, 4)) ?? 0) <= 26) {
      return casagrande;
    }

    // Por eje (PiezÃ³metros & AsentÃ­metros)
    // AsentÃ­metros: AD -> EJE_D, AE/AE1 -> EJE_E1
    if (upper.startsWith('AD')) return ejeD;
    if (upper.startsWith('AE')) return ejeE1;

    // PiezÃ³metros
    if (upper.startsWith('PA')) return ejeA;
    if (upper.startsWith('PB')) return ejeB;
    if (upper.startsWith('PC')) return ejeC; // PC31, PC41, etc. â†’ EJE_C
    if (upper.startsWith('PD')) return ejeD;

    // Logic for E vs E1:
    // Usually PE is E, but user asked for E1 specifically for some instruments?
    // Let's assume PE1... -> EJE_E1, PE... -> EJE_E
    if (upper.startsWith('PE1')) return ejeE1;
    if (upper.startsWith('PE')) return ejeE;

    if (upper.startsWith('PF')) return ejeF;
    if (upper.startsWith('PG')) return ejeG;

    // Aforadores
    if (upper == 'AFPP') return piePresa;
    if (upper.startsWith('GMD')) return galeriaMD;
    if (upper.startsWith('GSMI') || upper.startsWith('GIMI')) return galeriaMI;
    if (upper.startsWith('AFC')) return caverna;
    if (upper == 'ACUE') return acueducto;
    if (upper == 'ALIV') return aliviadero;

    return null;
  }
}

/// Rango esperado por instrumento+variable, sincronizado desde catálogo.
class InstrumentRange {
  final String variableCodigo;
  final double? min;
  final double? max;
  final String? metodo;
  final int? nMuestras;
  final int? version;

  const InstrumentRange({
    required this.variableCodigo,
    this.min,
    this.max,
    this.metodo,
    this.nMuestras,
    this.version,
  });

  factory InstrumentRange.fromJson(Map<String, dynamic> json) {
    return InstrumentRange(
      variableCodigo: (json['variable_codigo'] as String?)?.toUpperCase() ?? '',
      min: (json['min_val'] as num?)?.toDouble(),
      max: (json['max_val'] as num?)?.toDouble(),
      metodo: json['metodo'] as String?,
      nMuestras: json['n_muestras'] as int?,
      version: json['version'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'variable_codigo': variableCodigo,
        'min_val': min,
        'max_val': max,
        'metodo': metodo,
        'n_muestras': nMuestras,
        'version': version,
      };

  bool get hasRange => min != null && max != null;

  bool isOutOfRange(double value) {
    if (!hasRange) return false;
    return value < min! || value > max!;
  }

  String get fullLabel {
    if (!hasRange) return '';
    const names = {
      'DELTA_P_MCA': 'ΔP (mca)',
      'NIVEL_MCA': 'Nivel (mca)',
      'NIVEL_MSNM': 'Nivel (msnm)',
      'NIVEL_FREATICO': 'Nivel freat.',
      'CAUDAL': 'Caudal',
      'LECTURA_LU': 'Lectura LU',
      'INCLINACION': 'Inclinación',
      'DX': 'ΔX',
      'DY': 'ΔY',
      'DZ': 'ΔZ',
    };
    final name = names[variableCodigo] ?? variableCodigo;
    return '$name: ${min!.toStringAsFixed(2)} — ${max!.toStringAsFixed(2)}';
  }
}

/// Modelo de Instrumento para el catÃ¡logo local
/// Alineado con: GET /api/v1/catalog/instrumentos response
class Instrumento {
  /// ID del backend (null si solo existe localmente)
  final int? idInstrumento;

  /// CÃ³digo Ãºnico del instrumento (PK lÃ³gica en la app)
  final String codigo;

  /// Nombre descriptivo
  final String? nombre;

  /// Familia principal
  final FamiliaInstrumento familia;

  /// Subfamilia (clasificaciÃ³n mÃ¡s fina)
  final String? subfamilia;

  /// Estado activo/inactivo
  final bool activo;

  /// ParÃ¡metro por defecto para este tipo
  final String defaultParameter;

  /// Unidad por defecto
  final String defaultUnit;

  /// Rangos esperados por variable (sincronizados una vez vía catálogo)
  final List<InstrumentRange> rangos;

  Instrumento({
    this.idInstrumento,
    required this.codigo,
    this.nombre,
    required this.familia,
    this.subfamilia,
    this.activo = true,
    required this.defaultParameter,
    required this.defaultUnit,
    this.rangos = const [],
  });

  /// Constructor desde respuesta del catÃ¡logo del backend
  factory Instrumento.fromJson(Map<String, dynamic> json) {
    var familiaStr = json['familia'] as String? ?? 'PIEZOMETRO';

    // Check if we should override based on code pattern
    // This fixes cases where backend might send generic PIEZOMETRO or null for special types
    // or if the enum mapping defaults to Piezometro.
    final codigo = json['codigo'] as String;
    final backendFam = FamiliaInstrumento.fromBackend(familiaStr);
    final inferredFam = FamiliaInstrumento.inferFromCode(codigo);

    final finalFam = (backendFam == FamiliaInstrumento.piezometro &&
            inferredFam != FamiliaInstrumento.piezometro)
        ? inferredFam
        : backendFam;

    final defaultParam = json['default_parameter'] as String?;
    final defaultUnit = json['default_unit'] as String?;
    final rangosRaw = (json['rangos'] ?? json['ranges']) as List<dynamic>?;
    final rangos = rangosRaw
            ?.map((e) => InstrumentRange.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList() ??
        const <InstrumentRange>[];

    return Instrumento(
      idInstrumento: json['id_instrumento'] as int?,
      codigo: codigo,
      nombre: json['nombre'] as String?,
      familia: finalFam,
      subfamilia:
          (json['subfamilia'] as String?) ?? Subfamilia.inferFromCode(codigo),
      activo: json['activo'] as bool? ?? true,
      // Usar defaults del backend si estÃ¡n disponibles
      defaultParameter: defaultParam?.trim().isNotEmpty == true
          ? defaultParam!.trim()
          : _inferDefaultParameter(finalFam.backendValue),
      defaultUnit: defaultUnit?.trim().isNotEmpty == true
          ? defaultUnit!.trim()
          : _inferDefaultUnit(finalFam.backendValue),
      rangos: rangos,
    );
  }

  /// Constructor rÃ¡pido desde cÃ³digo (infiere familia y subfamilia)
  factory Instrumento.fromCode(String code) {
    final familia = FamiliaInstrumento.inferFromCode(code);
    final subfamilia = Subfamilia.inferFromCode(code);

    return Instrumento(
      codigo: code.toUpperCase(),
      familia: familia,
      subfamilia: subfamilia,
      defaultParameter: _inferDefaultParameter(familia.backendValue),
      defaultUnit: _inferDefaultUnit(familia.backendValue),
    );
  }

  /// Serializa para cache local
  Map<String, dynamic> toJson() {
    return {
      if (idInstrumento != null) 'id_instrumento': idInstrumento,
      'codigo': codigo,
      'nombre': nombre,
      'familia': familia.backendValue,
      'subfamilia': subfamilia,
      'activo': activo,
      'default_parameter': defaultParameter,
      'default_unit': defaultUnit,
      'rangos': rangos.map((r) => r.toJson()).toList(),
    };
  }

  /// Obtiene rango de una variable solo con match exacto.
  InstrumentRange? rangeForVariable(String variableCodigo) {
    if (rangos.isEmpty) return null;
    final target = variableCodigo.trim().toUpperCase();
    for (final r in rangos) {
      if (r.variableCodigo.toUpperCase() == target) return r;
    }
    return null;
  }

  String rangeDebugInfo(String variableCodigo) {
    final rawTarget = variableCodigo.trim();
    if (rawTarget.isEmpty) {
      return 'Instrumento $codigo sin variable solicitada para buscar rango';
    }
    if (rangos.isEmpty) {
      return 'Instrumento $codigo sin rangos configurados para $rawTarget';
    }
    final target = rawTarget.toUpperCase();
    final available = rangos
        .map((r) => r.variableCodigo.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toList();
    if (available.contains(target)) {
      return 'Instrumento $codigo con match exacto para $target';
    }
    final availableLabel = available.join(', ');
    return 'Instrumento $codigo sin match exacto para $target. '
        'Disponibles: $availableLabel';
  }

  /// Nombre para mostrar en UI
  String get displayName => nombre ?? codigo;

  /// Â¿Es lectura manual (Casagrande, freatÃ­metros, aforadores)?
  bool get esManual {
    if (familia == FamiliaInstrumento.casagrande) return true;
    if (subfamilia == Subfamilia.casagrande) return true;
    if (familia == FamiliaInstrumento.freatimetro) return true;
    if (familia == FamiliaInstrumento.aforador) return true;
    return false;
  }

  /// Â¿Es del CR10X?
  bool get esCR10X => !esManual && familia == FamiliaInstrumento.piezometro;

  /// ParÃ¡metro recomendado para ingesta (variable backend)
  String? get ingestaParameter {
    switch (familia) {
      case FamiliaInstrumento.piezometro:
        return 'LECTURA_CR10X';
      case FamiliaInstrumento.casagrande:
        return 'PROFUNDIDAD_M';
      case FamiliaInstrumento.freatimetro:
        return 'PROFUNDIDAD_M';
      case FamiliaInstrumento.aforador:
        return 'LECTURA_MANUAL';
      case FamiliaInstrumento.asentimetro:
        return 'LECTURA_LU';
      case FamiliaInstrumento.celdaPresion:
        return 'LECTURA';
      case FamiliaInstrumento.triaxial:
        final axis = _inferAxisFromCode();
        if (axis == 'T') return 'TEMPERATURA';
        return axis != null ? 'PERIODO_$axis' : 'PERIODO_X';
      case FamiliaInstrumento.uniaxial:
        return 'LECTURA_MM';
      case FamiliaInstrumento.termometro:
        return 'TEMPERATURA';
      case FamiliaInstrumento.clinometro:
        return 'LECTURA_MV';
      case FamiliaInstrumento.barometro:
        return 'PRESION';
      case FamiliaInstrumento.juntaPerimetral:
        return 'LECTURA_MM';
      case FamiliaInstrumento.limnimetro:
      case FamiliaInstrumento.embalse:
        return 'NIVEL_MSNM';
      case FamiliaInstrumento.convergencia:
        return 'CONVERGENCIA_MM';
      case FamiliaInstrumento.sismos:
        return 'MAGNITUD';
    }
  }

  /// Unidad recomendada para ingesta (segÃºn variable de entrada).
  /// Si devuelve null, se omite el campo `unit` en la API.
  String? get ingestaUnit {
    switch (familia) {
      case FamiliaInstrumento.piezometro:
      case FamiliaInstrumento.celdaPresion:
        return 'Hz';
      case FamiliaInstrumento.termometro:
        return '\u00B0C';
      case FamiliaInstrumento.asentimetro:
        return 'LU';
      case FamiliaInstrumento.clinometro:
        return 'mV';
      case FamiliaInstrumento.freatimetro:
      case FamiliaInstrumento.casagrande:
        return 'm';
      case FamiliaInstrumento.aforador:
        return 'cm'; // Default manual reading unit
      case FamiliaInstrumento.barometro:
        return 'hPa';
      case FamiliaInstrumento.embalse:
      case FamiliaInstrumento.limnimetro:
        return 'msnm';
      case FamiliaInstrumento.sismos:
        return 'Ric'; // Richter? Or just leave null. Backend sismos table has 'magnitud' float.
      default:
        return null; // Envia null o no envia
    }
  }

  String? _inferAxisFromCode() {
    final normalized =
        codigo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Check for Temperature (T) or Axis (X, Y, Z) at end only if preceded by number?
    // Usually J01X, J01Y, J01Z, J01T
    final match = RegExp(r'([XYZT])$').firstMatch(normalized);
    return match?.group(1);
  }

  @override
  String toString() => 'Instrumento($codigo, $familia)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Instrumento && other.codigo == codigo;

  @override
  int get hashCode => codigo.hashCode;
}

// =============================================================================
// Helpers privados
// =============================================================================

String _inferDefaultParameter(String familia) {
  switch (familia.toUpperCase()) {
    case 'PIEZOMETRO':
    case 'CASAGRANDE': // Familia propia
      return 'presion';
    case 'FREATIMETRO':
      return 'nivel';
    case 'AFORADOR':
      return 'altura';
    case 'ASENTIMETRO':
      return 'frecuencia';
    case 'CELDA_PRESION':
      return 'presion';
    case 'TRIAXIAL':
      return 'deformacion';
    case 'UNIAXIAL':
      return 'deformacion';
    case 'JUNTA_PERIMETRAL':
    case 'CLINOMETRO':
      return 'inclinacion';
    case 'TERMOMETRO':
      return 'temperatura';
    case 'LIMNIMETRO':
    case 'EMBALSE':
      return 'nivel';
    case 'BAROMETRO':
      return 'presion';
    default:
      return 'valor';
  }
}

String _inferDefaultUnit(String familia) {
  switch (familia.toUpperCase()) {
    case 'PIEZOMETRO':
    case 'CASAGRANDE': // Familia propia
      return 'mca';
    case 'FREATIMETRO':
      return 'm.s.n.m.';
    case 'AFORADOR':
      return 'mm';
    case 'ASENTIMETRO':
      return 'Hz\u00B2';
    case 'CELDA_PRESION':
      return 'MPa';
    case 'TRIAXIAL':
      return 'mm';
    case 'UNIAXIAL':
      return 'mm';
    case 'JUNTA_PERIMETRAL':
    case 'CLINOMETRO':
      return 'grados';
    case 'TERMOMETRO':
      return '\u00B0C';
    case 'LIMNIMETRO':
    case 'EMBALSE':
      return 'm.s.n.m.';
    case 'BAROMETRO':
      return 'mbar';
    default:
      return '';
  }
}
