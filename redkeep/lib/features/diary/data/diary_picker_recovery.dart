import '../domain/civil_date.dart';

import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../../voice/data/voice_store.dart';

/// Android can destroy the activity while the gallery is open. Keep its diary
/// address separately from the picker result; never attach it to another day.
class DiaryPickerRecovery {
  DiaryPickerRecovery({
    bool? android,
    Future<LostDataResponse> Function()? retrieve,
  }) : _android = android ?? Platform.isAndroid,
       _retrieve = retrieve ?? ImagePicker().retrieveLostData;
  final bool _android;
  final Future<LostDataResponse> Function() _retrieve;
  static Future<Map<String, dynamic>?>? _recovering;
  static const _key = 'redkeep.diary.picker';
  static int _epoch = 0;
  static Future<void> _tail = Future.value();
  final int _generation = _epoch;
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<Map<String, dynamic>?> read() async {
    final raw = await VoiceStore.storage.read(key: _key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(data['id'] as String) ||
          CivilDate.tryParse(data['date'] as String) == null ||
          DateTime.now().millisecondsSinceEpoch - (data['created'] as int) >
              86400000) {
        await clear();
        return null;
      }
      return data;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> begin(String date, String id) => _serial(() async {
    if (_generation != _epoch) return;
    await VoiceStore.storage.write(
      key: _key,
      value: jsonEncode({
        'date': date,
        'id': id,
        'created': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  });
  Future<Map<String, dynamic>?> recover() =>
      _recovering ??= _recover().whenComplete(() => _recovering = null);
  Future<Map<String, dynamic>?> _recover() async {
    final pending = await read();
    if (pending == null || !_android || pending['files'] is List) {
      return pending;
    }
    final response = await _retrieve();
    if (_generation != _epoch) return null;
    if (response.isEmpty || response.files?.isNotEmpty != true) {
      await clear();
      return null;
    }
    final recovered = {
      ...pending,
      'files': [for (final f in response.files!) f.path],
    };
    await _serial(() async {
      if (_generation == _epoch) {
        await VoiceStore.storage.write(key: _key, value: jsonEncode(recovered));
      }
    });
    return recovered;
  }

  Future<List<XFile>?> take(String date, String id) async {
    final pending = await recover();
    if (pending?['date'] != date ||
        pending?['id'] != id ||
        pending?['files'] is! List) {
      return null;
    }
    return [
      for (final path in pending!['files'] as List) XFile(path as String),
    ];
  }

  Future<void> clear() => _serial(() async {
    if (_generation == _epoch) await VoiceStore.storage.delete(key: _key);
  });
  Future<void> reset() async {
    _epoch++;
    await _serial(() => VoiceStore.storage.delete(key: _key));
  }
}
