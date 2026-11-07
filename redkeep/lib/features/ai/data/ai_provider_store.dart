import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ai_provider.dart';

abstract interface class ProtectedAiProviders {
  Future<String?> read();
  Future<void> write(String? value);
}

/// The key stays in the Keychain or Keystore, outside Drift, backups and sync.
class SecureAiProviders implements ProtectedAiProviders {
  static const _key = 'redkeep.ai.cloud.v1';
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'redkeep_companion',
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accountName: 'redkeep.companion',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  @override
  Future<String?> read() => storage.read(key: _key);
  @override
  Future<void> write(String? value) => value == null
      ? storage.delete(key: _key)
      : storage.write(key: _key, value: value);
}

class AiProviderStore {
  AiProviderStore(this.protected);
  final ProtectedAiProviders protected;

  Future<AiCloudSettings?> read() async {
    final raw = await protected.read();
    if (raw == null) return null;
    try {
      return AiCloudSettings.tryParse(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> write(AiCloudSettings settings) =>
      protected.write(jsonEncode(settings.toJson()));

  Future<void> clear() => protected.write(null);
}
