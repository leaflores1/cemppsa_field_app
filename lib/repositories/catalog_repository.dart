import 'package:flutter/foundation.dart';

class CatalogRepository extends ChangeNotifier {
  final Map<String, List<String>> _catalog = {
    'Piezómetros': ['PP1','PP2','PP3','PP4','PP5'],
    'Freatímetro': ['FR1','FR2','FR3'],
    'Acelerómetro': ['AC1','AC2'],
    'Aforadores': ['AF1','AF2'],
    'Caudalímetro': ['CQ1','CQ2'],
  };

  List<String> codesFor(String tipoMedicion) =>
      List<String>.from(_catalog[tipoMedicion] ?? const []);

  void setCodes(String tipoMedicion, List<String> codes) {
    _catalog[tipoMedicion] = List<String>.from(codes);
    notifyListeners();
  }
}
