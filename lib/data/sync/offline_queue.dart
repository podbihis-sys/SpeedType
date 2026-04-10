import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

/// Abstract base class for any operation that can be queued while offline
/// and replayed once connectivity is restored.
abstract class SyncOperation {
  final String id;
  final DateTime createdAt;
  final String type;

  SyncOperation({
    String? id,
    DateTime? createdAt,
    required this.type,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Runs the operation. Returns `true` on success, `false` on transient
  /// failure (will be retried), or throws for permanent failures.
  Future<bool> execute();

  /// Serialises the operation so it can be stored in the Hive box.
  Map<String, dynamic> toJson();

  /// Factory: reconstructs a concrete [SyncOperation] from a serialised map.
  static SyncOperation fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case SubmitScoreOperation.kType:
        return SubmitScoreOperation.fromJson(json);
      default:
        throw StateError('Unknown SyncOperation type: $type');
    }
  }
}

/// Queued "submit test score" operation. The execute() step delegates to
/// Firestore via a lazily-imported callback so this file stays dependency
/// light.
class SubmitScoreOperation extends SyncOperation {
  static const String kType = 'submit_score';

  /// Injectable uploader; tests and the data layer can override this.
  static Future<bool> Function(Map<String, dynamic> payload)? uploader;

  final Map<String, dynamic> payload;

  SubmitScoreOperation({
    super.id,
    super.createdAt,
    required this.payload,
  }) : super(type: kType);

  factory SubmitScoreOperation.fromJson(Map<String, dynamic> json) {
    return SubmitScoreOperation(
      id: json['id'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    );
  }

  @override
  Future<bool> execute() async {
    final fn = uploader;
    if (fn == null) {
      debugPrint('SubmitScoreOperation: no uploader registered');
      return false;
    }
    try {
      return await fn(payload);
    } catch (e) {
      debugPrint('SubmitScoreOperation.execute failed: $e');
      return false;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'payload': payload,
      };
}

/// Persistent FIFO queue of [SyncOperation] backed by Hive.
class OfflineQueue {
  OfflineQueue._internal();

  static final OfflineQueue _instance = OfflineQueue._internal();
  static OfflineQueue get instance => _instance;
  factory OfflineQueue() => _instance;

  static const String kBoxName = 'offline_queue';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(kBoxName);
    _initialized = true;
  }

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    await initialize();
    return _box!;
  }

  /// Appends an operation to the queue.
  Future<void> enqueue(SyncOperation op) async {
    final box = await _getBox();
    await box.put(op.id, jsonEncode(op.toJson()));
  }

  /// Returns all queued operations, oldest first.
  Future<List<SyncOperation>> getAll() async {
    final box = await _getBox();
    final ops = <SyncOperation>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        ops.add(SyncOperation.fromJson(map));
      } catch (e) {
        debugPrint('OfflineQueue: failed to decode $key: $e');
      }
    }
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  /// Removes a single operation by id.
  Future<void> remove(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Removes every queued operation.
  Future<void> clear() async {
    final box = await _getBox();
    await box.clear();
  }

  Future<int> length() async {
    final box = await _getBox();
    return box.length;
  }
}
