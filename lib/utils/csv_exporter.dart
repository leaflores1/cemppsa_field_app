// ==============================================================================
// CEMPPSA Field App - CsvExporter
// Utilidad para exportar planillas a archivos CSV
// ==============================================================================

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../data/models/planilla.dart';

class CsvExporter {
  /// Exporta una sola planilla a CSV
  static Future<String> exportPlanilla(Planilla planilla) async {
    final csv = _generateCsv([planilla]);
    final filename = _generateFilename(planilla);
    return await _saveFile(filename, csv);
  }

  /// Exporta múltiples planillas a un solo CSV
  static Future<String> exportMultiple(List<Planilla> planillas) async {
    final csv = _generateCsv(planillas);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'cemppsa_export_$timestamp.csv';
    return await _saveFile(filename, csv);
  }

  /// Genera el contenido CSV
  static String _generateCsv(List<Planilla> planillas) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln([
      'batch_uuid',
      'tipo_planilla',
      'instrument_code',
      'parameter',
      'unit',
      'value',
      'measured_at',
      'notes',
      'created_at',
      'device_id',
      'technician_id',
    ].join(','));

    // Filas
    for (final planilla in planillas) {
      for (final lectura in planilla.lecturas) {
        buffer.writeln([
          planilla.batchUuid,
          planilla.tipo.name,
          lectura.instrumentCode,
          lectura.parameter,
          lectura.unit,
          lectura.value.toString(),
          lectura.measuredAt.toIso8601String(),
          _escapeCsv(lectura.notes ?? ''),
          planilla.createdAt.toIso8601String(),
          planilla.deviceId,
          planilla.technicianId,
        ].join(','));
      }
    }

    return buffer.toString();
  }

  /// Genera nombre de archivo para una planilla
  static String _generateFilename(Planilla planilla) {
    final tipo = planilla.tipo.name.toUpperCase();
    final fecha = DateFormat('yyyyMMdd').format(planilla.createdAt);
    final uuid = planilla.batchUuid.substring(0, 8);
    return 'cemppsa_${tipo}_${fecha}_$uuid.csv';
  }

  /// Guarda el archivo y devuelve la ruta
  static Future<String> _saveFile(String filename, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final file = File('${exportDir.path}/$filename');
    await file.writeAsString(content);

    return file.path;
  }

  /// Abre el archivo exportado
  static Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }

  /// Escapa caracteres especiales para CSV
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Obtiene el directorio de exportaciones
  static Future<Directory> getExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    return exportDir;
  }

  /// Lista archivos exportados
  static Future<List<FileSystemEntity>> listExports() async {
    final dir = await getExportDirectory();
    return dir.listSync()
        .where((f) => f.path.endsWith('.csv'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  /// Elimina un archivo exportado
  static Future<void> deleteExport(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Limpia exports antiguos (más de N días)
  static Future<int> cleanOldExports({int daysOld = 30}) async {
    final dir = await getExportDirectory();
    final cutoff = DateTime.now().subtract(Duration(days: daysOld));
    int deleted = 0;

    for (final file in dir.listSync()) {
      if (file is File && file.path.endsWith('.csv')) {
        final modified = file.statSync().modified;
        if (modified.isBefore(cutoff)) {
          await file.delete();
          deleted++;
        }
      }
    }

    return deleted;
  }
}
