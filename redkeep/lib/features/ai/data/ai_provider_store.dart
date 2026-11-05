import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ai_provider.dart';
import 'ai_job_store.dart' show SecureAiTasks;

abstract interface class ProtectedAiProviders {
  Future<String?> read();
  Future<void> write(String? value);
}

/// Tokens stay in the Keychain or Keystore, outside Drift, backups and sync.
class SecureAiProviders implements ProtectedAiProviders {
  static const _key = 'redkeep.ai.providers.v1';
  static const FlutterSecureStorage _storage = SecureAiTasks.storage;
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String? value) => value == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: value);
}

class AiProviderStore {
  AiProviderStore(this.protected);
  final ProtectedAiProviders protected;

  Future<List<AiProviderConnection>> read() async {
    final raw = await protected.read();
    if (raw == null) return const [];
    try {
      final values = jsonDecode(raw);
      if (values is! List) return const [];
      return [
        for (final value in values) ?AiProviderConnection.tryParse(value),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(List<AiProviderConnection> connections) => protected.write(
    jsonEncode([for (final connection in connections) connection.toJson()]),
  );

  Future<void> clear() => protected.write(null);
}
