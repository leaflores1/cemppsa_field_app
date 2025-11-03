import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cemppsa_field_app/services/network_manager.dart';
import 'package:cemppsa_field_app/services/offline_storage.dart';
import 'package:cemppsa_field_app/repositories/planillas_repository.dart';

class SyncService {
  final NetworkManager net;
  final OfflineStorage offline;
  final PlanillasRepository repo;

  SyncService({required this.net, required this.offline, required this.repo});

  VoidCallback? _netListener;
  Timer? _tick;

  void start() {
    _netListener = () => _maybeFlush();
    net.addListener(_netListener!);

    _tick = Timer.periodic(const Duration(seconds: 20), (_) => _maybeFlush());

    _maybeFlush();
  }

  Future<void> _maybeFlush() async {
    final sentIds = await offline.flushIfPossible(net);
    if (sentIds.isNotEmpty) {
      repo.markAsSentBatchIds(sentIds);
    }
  }

  void dispose() {
    if (_netListener != null) net.removeListener(_netListener!);
    _tick?.cancel();
  }
}
