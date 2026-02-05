// ==============================================================================
// CEMPPSA Field App - Modelo Instrumento
// Alineado con: backend Instrumento (familia_instrumento_enum)
// ==============================================================================

/// Familia de instrumento según el backend
/// Mapea exactamente a: familia_instrumento_enum en MySQL
enum FamiliaInstrumento {
  piezometro('PIEZOMETRO', 'Piezómetro'),
  casagrande('CASAGRANDE', 'Casagrande'), // Familia propia
  freatimetro('FREATIMETRO', 'Freatímetro'),
  asentimetro('ASENTIMETRO', 'Asentímetro'),
  aforador('AFORADOR', 'Aforador'),
  celdaPresion('CELDA_PRESION', 'Celda de Presión'),
  triaxial('TRIAXIAL', 'Triaxial'),
  uniaxial('UNIAXIAL', 'Uniaxial'),
  juntaPerimetral('JUNTA_PERIMETRAL', 'Junta Perimetral'),
  termometro('TERMOMETRO', 'Termómetro'),
  clinometro('CLINOMETRO', 'Clinómetro'),
  limnimetro('LIMNIMETRO', 'Limnimetro'),
  barometro('BAROMETRO', 'Barómetro'),
  convergencia('CONVERGENCIA', 'Convergencia'),
  embalse('EMBALSE', 'Embalse');

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

  /// Infiere familia a partir del código del instrumento
  static FamiliaInstrumento inferFromCode(String code) {
    final upper = code.toUpperCase();

    // Casagrande (lecturas manuales en cámara de compuertas)
    // Ahora es familia propia si empieza con PC y 2 dígitos
    if (RegExp(r'^PC\d{2}').hasMatch(upper)) {
      return FamiliaInstrumento.casagrande;
    }

    // Piezómetros de cuerda vibrante (P + letra de eje)
    if (RegExp(r'^P[ABCDEFG]').hasMatch(upper)) {
      return FamiliaInstrumento.piezometro;
    }

    // Freatímetros
    if (upper.startsWith('PP') || upper.startsWith('D1') || upper.startsWith('D2')) {
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

    // Asentímetros
    if (upper.startsWith('AD') || upper.startsWith('AE')) {
      return FamiliaInstrumento.asentimetro;
    }

    // Triaxiales
    if (RegExp(r'^J\d+[XYZ]?').hasMatch(upper)) {
      return FamiliaInstrumento.triaxial;
    }

    // Uniaxiales
    if (RegExp(r'^U\d+').hasMatch(upper)) {
      return FamiliaInstrumento.uniaxial;
    }

    // Clinómetros (juntas perimetrales)
    if (upper.startsWith('JP')) {
      return FamiliaInstrumento.juntaPerimetral;
    }

    // Termómetros
    if (upper.startsWith('TE') || upper.startsWith('TG') || RegExp(r'^T\d').hasMatch(upper)) {
      return FamiliaInstrumento.termometro;
    }

    // Celdas de presión
    if (upper.startsWith('CP') || upper.startsWith('CQ')) {
      return FamiliaInstrumento.celdaPresion;
    }

    // Limnimetro
    if (upper.contains('LIMNI')) {
      return FamiliaInstrumento.limnimetro;
    }

    // Barómetro
    if (upper.contains('BAR') || upper == 'P_BAR') {
      return FamiliaInstrumento.barometro;
    }

    // Default
    return FamiliaInstrumento.piezometro;
  }
}

/// Subfamilias comunes (para clasificación más fina)
/// Corresponde al campo `subfamilia` VARCHAR(50) del backend
class Subfamilia {
  // Piezómetros
  static const String casagrande = 'CASAGRANDE';
  static const String ejeA = 'EJE_A';
  static const String ejeB = 'EJE_B';
  static const String ejeC = 'EJE_C';
  static const String ejeD = 'EJE_D';
  static const String ejeE = 'EJE_E';
  static const String ejeF = 'EJE_F';
  static const String ejeG = 'EJE_G';

  // Aforadores
  static const String piePresa = 'PIE_PRESA';
  static const String galeriaMD = 'GMD';
  static const String galeriaMI = 'GMI';
  static const String caverna = 'CAVERNA';
  static const String acueducto = 'ACUEDUCTO';
  static const String aliviadero = 'ALIVIADERO';

  /// Infiere subfamilia desde el código
  static String? inferFromCode(String code) {
    final upper = code.toUpperCase();

    // Piezómetros Casagrande (lectura manual)
    if (RegExp(r'^PC\d{2}').hasMatch(upper) && !RegExp(r'^PC\d{3}').hasMatch(upper)) {
      return casagrande;
    }

    // Por eje
    if (upper.startsWith('PA')) return ejeA;
    if (upper.startsWith('PB')) return ejeB;
    if (upper.startsWith('PC')) return ejeC;
    if (upper.startsWith('PD')) return ejeD;
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

/// Modelo de Instrumento para el catálogo local
/// Alineado con: GET /api/v1/catalog/instrumentos response
class Instrumento {
  /// ID del backend (null si solo existe localmente)
  final int? idInstrumento;

  /// Código único del instrumento (PK lógica en la app)
  final String codigo;

  /// Nombre descriptivo
  final String? nombre;

  /// Familia principal
  final FamiliaInstrumento familia;

  /// Subfamilia (clasificación más fina)
  final String? subfamilia;

  /// Estado activo/inactivo
  final bool activo;

  /// Parámetro por defecto para este tipo
  final String defaultParameter;

  /// Unidad por defecto
  final String defaultUnit;

  Instrumento({
    this.idInstrumento,
    required this.codigo,
    this.nombre,
    required this.familia,
    this.subfamilia,
    this.activo = true,
    required this.defaultParameter,
    required this.defaultUnit,
  });

  /// Constructor desde respuesta del catálogo del backend
  factory Instrumento.fromJson(Map<String, dynamic> json) {
    final familiaStr = json['familia'] as String? ?? 'PIEZOMETRO';
    final defaultParam = json['default_parameter'] as String?;
    final defaultUnit = json['default_unit'] as String?;

    return Instrumento(
      idInstrumento: json['id_instrumento'] as int?,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String?,
      familia: FamiliaInstrumento.fromBackend(familiaStr),
      subfamilia: json['subfamilia'] as String?,
      activo: json['activo'] as bool? ?? true,
      // Usar defaults del backend si están disponibles
      defaultParameter: defaultParam?.trim().isNotEmpty == true
          ? defaultParam!.trim()
          : _inferDefaultParameter(familiaStr),
      defaultUnit: defaultUnit?.trim().isNotEmpty == true
          ? defaultUnit!.trim()
          : _inferDefaultUnit(familiaStr),
    );
  }

  /// Constructor rápido desde código (infiere familia y subfamilia)
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
    };
  }

  /// Nombre para mostrar en UI
  String get displayName => nombre ?? codigo;

  /// ¿Es lectura manual (Casagrande, freatímetros, aforadores)?
  bool get esManual {
    if (familia == FamiliaInstrumento.casagrande) return true;
    if (subfamilia == Subfamilia.casagrande) return true;
    if (familia == FamiliaInstrumento.freatimetro) return true;
    if (familia == FamiliaInstrumento.aforador) return true;
    return false;
  }

  /// ¿Es del CR10X?
  bool get esCR10X => !esManual && familia == FamiliaInstrumento.piezometro;

  /// Parámetro recomendado para ingesta (variable backend)
  String? get ingestaParameter {
    switch (familia) {
      case FamiliaInstrumento.piezometro:
        return 'LECTURA_CR10X';
      case FamiliaInstrumento.casagrande:
        return 'LECTURA';
      case FamiliaInstrumento.freatimetro:
        return 'PROFUNDIDAD_M';
      case FamiliaInstrumento.aforador:
        return 'ALTURA_MM';
      case FamiliaInstrumento.asentimetro:
        return 'LECTURA_LU';
      case FamiliaInstrumento.celdaPresion:
        return 'LECTURA_CR10X';
      case FamiliaInstrumento.triaxial:
        final axis = _inferAxisFromCode();
        return axis != null ? 'EJE_$axis' : 'EJE_X';
      case FamiliaInstrumento.uniaxial:
        return 'LECTURA_MM';
      case FamiliaInstrumento.termometro:
        return 'LECTURA_CR10X';
      case FamiliaInstrumento.clinometro:
        return 'LECTURA_MV';
      case FamiliaInstrumento.barometro:
        return 'PRESION_MBAR';
      case FamiliaInstrumento.juntaPerimetral:
        return 'LECTURA_MM';
      case FamiliaInstrumento.limnimetro:
      case FamiliaInstrumento.embalse:
        return 'NIVEL_EMBALSE';
      case FamiliaInstrumento.convergencia:
        return 'CONVERGENCIA_MM';
    }
  }

  /// Unidad recomendada para ingesta (según variable de entrada).
  /// Si devuelve null, se omite el campo `unit` en la API.
  String? get ingestaUnit {
    switch (familia) {
      case FamiliaInstrumento.piezometro:
      case FamiliaInstrumento.celdaPresion:
      case FamiliaInstrumento.termometro:
        return 'Hz';
      case FamiliaInstrumento.asentimetro:
        return 'LU';
      case FamiliaInstrumento.clinometro:
        return 'mV';
      case FamiliaInstrumento.freatimetro:
        return 'm';
      case FamiliaInstrumento.aforador:
        return 'mm';
      case FamiliaInstrumento.barometro:
        return 'mbar';
      default:
        return null;
    }
  }

  String? _inferAxisFromCode() {
    final normalized = codigo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final match = RegExp(r'([XYZ])$').firstMatch(normalized);
    return match?.group(1);
  }

  @override
  String toString() => 'Instrumento($codigo, $familia)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Instrumento && other.codigo == codigo;

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
      return 'Hz²';
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
      return '°C';
    case 'LIMNIMETRO':
    case 'EMBALSE':
      return 'm.s.n.m.';
    case 'BAROMETRO':
      return 'mbar';
    default:
      return '';
  }
}
