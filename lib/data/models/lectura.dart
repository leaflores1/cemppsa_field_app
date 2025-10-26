import 'package:flutter/foundation.dart';

@immutable
class Lectura {
  final String instrumento;
  final String valor; // si luego lo quieres numérico, cambiamos a double

  const Lectura({
    required this.instrumento,
    required this.valor,
  });
}
