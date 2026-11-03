import 'dart:async';
import 'dart:convert';

import '../engine/sync_client.dart';

enum SyncDeviceRole { unknown, primary, secondary }

/// Awaitable persistence. Hosts commit authoritative writing and outbox changes
/// together; synchronous memory stores remain available for isolated tests.
abstract interface class SyncKeyValueStore {
  FutureOr<String?> read(String key);
  FutureOr<void> write(String key, String value);
  FutureOr<void> remove(String key);
  FutureOr<List<String>> keys(String prefix);
  FutureOr<void> clear();
}

class MemorySyncKeyValueStore implements SyncKeyValueStore {
  final _values = <String, String>{};
  @override
  String? read(String key) => _values[key];
  @override
  void write(String key, String value) => _values[key] = value;
  @override
  void remove(String key) => _values.remove(key);
  @override
  List<String> keys(String prefix) =>
      _values.keys.where((k) => k.startsWith(prefix)).toList();
  @override
  void clear() => _values.clear();
}

class PendingCreation {
  final String id;
  final String type;
  final String documentId;
  final Map<String, dynamic> payload;
  const PendingCreation({
    required this.id,
    required this.type,
    required this.documentId,
    required this.payload,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'document_id': documentId,
    'payload': payload,
  };
  factory PendingCreation.fromJson(Map<String, dynamic> json) =>
      PendingCreation(
        id: json['id'] as String,
        type: json['type'] as String,
        documentId: json['document_id'] as String,
        payload: (json['payload'] as Map).cast<String, dynamic>(),
      );
}

class SyncStateStore {
  final SyncKeyValueStore storage;
  final String deviceId;
  final DateTime Function() now;
  SyncStateStore({
    required this.storage,
    required this.deviceId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  PrimaryDevice? _primary;
  PrimaryDevice? get primary => _primary;
  SyncDeviceRole get role => primary == null
      ? SyncDeviceRole.unknown
      : primary!.deviceId == deviceId
      ? SyncDeviceRole.primary
      : SyncDeviceRole.secondary;
  bool get canEdit => role != SyncDeviceRole.secondary;
  Future<void> initialize() async {
    final value = await _read('role');
    _primary = value == null ? null : PrimaryDevice.fromJson(value);
  }

  Future<Map<String, dynamic>?> _read(String key) async {
    final value = await storage.read(key);
    return value == null
        ? null
        : (jsonDecode(value) as Map).cast<String, dynamic>();
  }

  Future<void> _write(String key, Object value) async =>
      storage.write(key, jsonEncode(value));
  Future<void> bind(String backend, String account) async {
    final owner = '$backend/$account';
    final previous = await storage.read('owner');
    if (previous != null && previous != owner) {
      throw StateError(
        'Local sync metadata belongs to another account. Reset it first.',
      );
    }
    await storage.write('owner', owner);
  }

  Future<void> setPrimary(PrimaryDevice value) async {
    await _write('role', value.toJson());
    _primary = value;
  }

  Future<void> edited(String type, String id, [String field = 'record']) =>
      _write('edit/$type/$id/$field', {
        'at': now().toUtc().toIso8601String(),
        'dirty': true,
      });
  Future<bool> dirty(String type, String id, [String? field]) async {
    if (field != null) {
      return (await _read('edit/$type/$id/$field'))?['dirty'] == true;
    }
    for (final key in await storage.keys('edit/$type/$id/')) {
      if ((await _read(key))?['dirty'] == true) return true;
    }
    return false;
  }

  Future<bool> protected(
    String type,
    String id,
    String field,
    DateTime at,
  ) async {
    final value = await _read('edit/$type/$id/$field');
    return value != null &&
        at.toUtc().difference(DateTime.parse(value['at'] as String)) <
            const Duration(minutes: 2);
  }

  Future<void> cleanField(String type, String id, String field) async {
    final key = 'edit/$type/$id/$field';
    final value = await _read(key);
    if (value != null) {
      value['dirty'] = false;
      await _write(key, value);
    }
  }

  Future<void> clean(String type, String id) async {
    for (final key in await storage.keys('edit/$type/$id/')) {
      final value = (await _read(key))!;
      value['dirty'] = false;
      await _write(key, value);
    }
  }

  Future<void> enqueue(PendingCreation value) async {
    final key = 'operation/${value.type}/${value.id}';
    if (await storage.read(key) == null) await _write(key, value.toJson());
  }

  Future<List<PendingCreation>> get pendingCreations async {
    final result = <PendingCreation>[];
    for (final key in await storage.keys('operation/')) {
      result.add(PendingCreation.fromJson((await _read(key))!));
    }
    return result;
  }

  Future<void> acknowledgeCreation(PendingCreation value) async =>
      storage.remove('operation/${value.type}/${value.id}');
  Future<RemoteDocument?> baseline(String type, String id) async {
    final value = await _read('baseline/$type/$id');
    return value == null ? null : RemoteDocument.fromJson(value);
  }

  Future<void> saveBaseline(RemoteDocument value) =>
      _write('baseline/${value.type}/${value.documentId}', value.toJson());
  Future<bool> get hasBlockedDocuments async =>
      (await storage.keys('blocked/')).isNotEmpty;
  Future<void> forgetBaseline(String type, String id) async =>
      storage.remove('baseline/$type/$id');
  Future<bool> blocked(String type, String id) async =>
      await storage.read('blocked/$type/$id') != null;
  Future<void> block(String type, String id) async =>
      storage.write('blocked/$type/$id', '1');
  Future<void> unblock(String type, String id) async =>
      storage.remove('blocked/$type/$id');
  Future<void> clear() async {
    await storage.clear();
    _primary = null;
  }
}
