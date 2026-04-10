import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/auth_service.dart';
import 'offline_queue.dart';

/// Singleton that reconciles local data with the Firestore user document
/// whenever the user logs in, and drains the offline queue as connectivity
/// permits.
class AccountSyncService {
  AccountSyncService._internal();

  static final AccountSyncService _instance = AccountSyncService._internal();
  static AccountSyncService get instance => _instance;
  factory AccountSyncService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService.instance;
  final OfflineQueue _queue = OfflineQueue.instance;

  bool _syncing = false;
  Timer? _backgroundTimer;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  // ---------------------------------------------------------------------------
  // Entry points
  // ---------------------------------------------------------------------------

  /// Called immediately after a successful login (Google / Apple). Loads the
  /// remote user document; if it does not exist we upload all local data, if
  /// it does we merge.
  Future<void> syncAfterLogin({
    required Map<String, dynamic> localData,
  }) async {
    final uid = _auth.userId;
    if (uid == null) {
      debugPrint('AccountSyncService: no uid, skipping syncAfterLogin');
      return;
    }
    if (_syncing) return;
    _syncing = true;

    try {
      final docRef = _usersCol.doc(uid);
      final snap = await docRef.get();

      if (!snap.exists) {
        await _uploadLocalData(uid, localData);
      } else {
        final remote = snap.data() ?? <String, dynamic>{};
        final merged = _mergeData(localData, remote);
        await docRef.set(merged, SetOptions(merge: true));
      }

      // Drain anything that was queued while offline.
      await processOfflineQueue();
    } catch (e, st) {
      debugPrint('AccountSyncService.syncAfterLogin error: $e\n$st');
    } finally {
      _syncing = false;
    }
  }

  /// Conflict resolution: for numeric progression we keep the max; for lists
  /// (test history) we union by UUID.
  @visibleForTesting
  Map<String, dynamic> _mergeData(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final merged = <String, dynamic>{...remote};

    int _maxInt(dynamic a, dynamic b) {
      final ai = (a is num) ? a.toInt() : 0;
      final bi = (b is num) ? b.toInt() : 0;
      return ai > bi ? ai : bi;
    }

    double _maxDouble(dynamic a, dynamic b) {
      final ad = (a is num) ? a.toDouble() : 0.0;
      final bd = (b is num) ? b.toDouble() : 0.0;
      return ad > bd ? ad : bd;
    }

    // Scalar "take the max" fields.
    merged['streak'] = _maxInt(local['streak'], remote['streak']);
    merged['level'] = _maxInt(local['level'], remote['level']);
    merged['xp'] = _maxInt(local['xp'], remote['xp']);
    merged['bestWpm'] = _maxDouble(local['bestWpm'], remote['bestWpm']);

    // Union the test history by UUID.
    final localHistory = _asListOfMaps(local['history']);
    final remoteHistory = _asListOfMaps(remote['history']);
    final byId = <String, Map<String, dynamic>>{};
    for (final e in remoteHistory) {
      final id = (e['id'] ?? e['uuid'])?.toString();
      if (id != null) byId[id] = e;
    }
    for (final e in localHistory) {
      final id = (e['id'] ?? e['uuid'])?.toString();
      if (id != null && !byId.containsKey(id)) {
        byId[id] = e;
      }
    }
    merged['history'] = byId.values.toList();

    // Preserve any local-only top-level keys we haven't explicitly merged.
    for (final entry in local.entries) {
      merged.putIfAbsent(entry.key, () => entry.value);
    }

    merged['lastSyncedAt'] = FieldValue.serverTimestamp();
    return merged;
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  Future<void> _uploadLocalData(
    String uid,
    Map<String, dynamic> localData,
  ) async {
    final payload = <String, dynamic>{
      ...localData,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSyncedAt': FieldValue.serverTimestamp(),
    };
    await _usersCol.doc(uid).set(payload, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Background + offline queue
  // ---------------------------------------------------------------------------

  /// Schedules a lightweight periodic sync. Call once after login.
  void backgroundSync({Duration interval = const Duration(minutes: 15)}) {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(interval, (_) async {
      if (_auth.userId == null || _auth.isAnonymous) return;
      await processOfflineQueue();
    });
  }

  void stopBackgroundSync() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  /// Drains the [OfflineQueue], removing successfully-executed operations.
  Future<void> processOfflineQueue() async {
    try {
      final ops = await _queue.getAll();
      for (final op in ops) {
        try {
          final ok = await op.execute();
          if (ok) {
            await _queue.remove(op.id);
          }
        } catch (e) {
          debugPrint('AccountSyncService: op ${op.id} failed: $e');
        }
      }
    } catch (e) {
      debugPrint('AccountSyncService.processOfflineQueue error: $e');
    }
  }
}
