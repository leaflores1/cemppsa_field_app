import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'package:cemppsa_field_app/data/models/planilla.dart';

class CsvExporter {
  /// ANDROID: intenta guardar en /storage/emulated/0/Download
  /// Fallback (Android sin permisos) y Desktop/iOS: Downloads si existe, sino Documents de la app.
  static Future<Uri?> exportPlanilla(Planilla p) async {
    final csv = _buildCsv(p);
    final bytes = Uint8List.fromList(csv.codeUnits);
    final fileName = 'planilla_${DateFormat("yyyyMMdd_HHmm").format(p.fecha)}.csv';

    // --- ANDROID: intento directo a la carpeta pública "Download"
    if (Platform.isAndroid) {
      try {
        final downloads = Directory('/storage/emulated/0/Download');
        if (await downloads.exists()) {
          final file = File(path.join(downloads.path, fileName));
          await file.writeAsBytes(bytes, flush: true);
          await OpenFilex.open(file.path).catchError((_) {});
          return file.uri;
        }
      } catch (_) {
        // si falla, seguimos con el fallback
      }
    }

    // --- Fallback Desktop/iOS/Android: Downloads del SO o Documents de la app
    final dir = await (getDownloadsDirectory() ?? getApplicationDocumentsDirectory());
    final file = File(path.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path).catchError((_) {});
    return file.uri;
  }

  static Future<Directory> getDownloadsDirectory() async {
    // path_provider trae esta API en desktop; en Android suele ser null,
    // así que devolvemos null para que el caller use Documents de la app.
    try {
      return await getApplicationSupportDirectory(); // placeholder si tu SDK no expone getDownloadsDirectory
    } catch (_) {
      return await getApplicationDocumentsDirectory();
    }
  }

  static String _buildCsv(Planilla p) {
    final b = StringBuffer()
      ..writeln('Planilla;${p.tipoMedicion}')
      ..writeln('Tecnico;${p.tecnico}')
      ..writeln('Fecha;${DateFormat('dd/MM/yyyy HH:mm').format(p.fecha)}')
      ..writeln('')
      ..writeln('Instrumento;Valor');
    for (final l in p.lecturas) {
      b.writeln('${l.instrumento};${l.valor}');
    }
    return b.toString();
  }
}
