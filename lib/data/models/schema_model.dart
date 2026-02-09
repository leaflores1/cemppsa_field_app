class MobileSchema {
  final String familia;
  final List<SchemaInstrument> instruments;
  final List<SchemaVariable> variables;
  final String payloadFormat;

  MobileSchema({
    required this.familia,
    required this.instruments,
    required this.variables,
    required this.payloadFormat,
  });

  factory MobileSchema.fromJson(Map<String, dynamic> json) {
    return MobileSchema(
      familia: json['familia'] ?? '',
      instruments: (json['instruments'] as List<dynamic>?)
              ?.map((e) => SchemaInstrument.fromJson(e))
              .toList() ??
          [],
      variables: (json['variables'] as List<dynamic>?)
              ?.map((e) => SchemaVariable.fromJson(e))
              .toList() ??
          [],
      payloadFormat: json['payload_format'] ?? 'PIVOT',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'familia': familia,
      'instruments': instruments.map((e) => e.toJson()).toList(),
      'variables': variables.map((e) => e.toJson()).toList(),
      'payload_format': payloadFormat,
    };
  }
}

class SchemaInstrument {
  final int id;
  final String codigo;
  final String nombre;
  final String? ubicacion;

  SchemaInstrument({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.ubicacion,
  });

  factory SchemaInstrument.fromJson(Map<String, dynamic> json) {
    return SchemaInstrument(
      id: json['id'] ?? 0,
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      ubicacion: json['ubicacion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'ubicacion': ubicacion,
    };
  }
}

class SchemaVariable {
  final String code;
  final String name;
  final String unit;
  final String type;
  final bool required;
  final bool isDefault;

  SchemaVariable({
    required this.code,
    required this.name,
    required this.unit,
    required this.type,
    this.required = false,
    this.isDefault = false,
  });

  factory SchemaVariable.fromJson(Map<String, dynamic> json) {
    return SchemaVariable(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      unit: json['unit'] ?? '',
      type: json['type'] ?? 'RAW',
      required: json['required'] ?? false,
      isDefault: json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'unit': unit,
      'type': type,
      'required': required,
      'is_default': isDefault,
    };
  }
}
