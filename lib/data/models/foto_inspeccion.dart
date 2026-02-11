import 'package:uuid/uuid.dart';

enum FotoSyncStatus {
  pendiente,
  sincronizando,
  sincronizada,
  error,
}

class FotoInspeccion {
  final String localId;
  final String localPath;
  final String mesOperativo;
  final String? loteUuid;
  final String? eventoCodigo;
  final String? eventoNombre;
  final String? ubicacion;
  final DateTime takenAt;
  final DateTime createdAt;
  final String? comentario;
  final int retries;
  final DateTime? nextRetryAt;
  final String? lastError;
  final int? remoteId;
  final String? remotePublicUuid;
  final FotoSyncStatus status;

  FotoInspeccion({
    String? localId,
    required this.localPath,
    required this.mesOperativo,
    this.loteUuid,
    this.eventoCodigo,
    this.eventoNombre,
    this.ubicacion,
    required this.takenAt,
    DateTime? createdAt,
    this.comentario,
    this.retries = 0,
    this.nextRetryAt,
    this.lastError,
    this.remoteId,
    this.remotePublicUuid,
    this.status = FotoSyncStatus.pendiente,
  })  : localId = localId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get canRetryNow {
    if (status == FotoSyncStatus.sincronizada) return false;
    if (nextRetryAt == null) return true;
    return DateTime.now().isAfter(nextRetryAt!);
  }

  FotoInspeccion copyWith({
    String? localPath,
    String? mesOperativo,
    String? loteUuid,
    String? eventoCodigo,
    String? eventoNombre,
    String? ubicacion,
    DateTime? takenAt,
    String? comentario,
    int? retries,
    DateTime? nextRetryAt,
    String? lastError,
    int? remoteId,
    String? remotePublicUuid,
    FotoSyncStatus? status,
  }) {
    return FotoInspeccion(
      localId: localId,
      localPath: localPath ?? this.localPath,
      mesOperativo: mesOperativo ?? this.mesOperativo,
      loteUuid: loteUuid ?? this.loteUuid,
      eventoCodigo: eventoCodigo ?? this.eventoCodigo,
      eventoNombre: eventoNombre ?? this.eventoNombre,
      ubicacion: ubicacion ?? this.ubicacion,
      takenAt: takenAt ?? this.takenAt,
      createdAt: createdAt,
      comentario: comentario ?? this.comentario,
      retries: retries ?? this.retries,
      nextRetryAt: nextRetryAt,
      lastError: lastError,
      remoteId: remoteId ?? this.remoteId,
      remotePublicUuid: remotePublicUuid ?? this.remotePublicUuid,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'local_path': localPath,
      'mes_operativo': mesOperativo,
      'lote_uuid': loteUuid,
      'evento_codigo': eventoCodigo,
      'evento_nombre': eventoNombre,
      'ubicacion': ubicacion,
      'taken_at': takenAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'comentario': comentario,
      'retries': retries,
      'next_retry_at': nextRetryAt?.toIso8601String(),
      'last_error': lastError,
      'remote_id': remoteId,
      'remote_public_uuid': remotePublicUuid,
      'status': status.name,
    };
  }

  factory FotoInspeccion.fromJson(Map<String, dynamic> json) {
    return FotoInspeccion(
      localId: json['local_id'] as String?,
      localPath: json['local_path'] as String,
      mesOperativo: json['mes_operativo'] as String,
      loteUuid: json['lote_uuid'] as String?,
      eventoCodigo: json['evento_codigo'] as String?,
      eventoNombre: json['evento_nombre'] as String?,
      ubicacion: json['ubicacion'] as String?,
      takenAt: DateTime.parse(json['taken_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      comentario: json['comentario'] as String?,
      retries: json['retries'] as int? ?? 0,
      nextRetryAt: json['next_retry_at'] != null
          ? DateTime.parse(json['next_retry_at'] as String)
          : null,
      lastError: json['last_error'] as String?,
      remoteId: json['remote_id'] as int?,
      remotePublicUuid: json['remote_public_uuid'] as String?,
      status: FotoSyncStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?),
        orElse: () => FotoSyncStatus.pendiente,
      ),
    );
  }
}
