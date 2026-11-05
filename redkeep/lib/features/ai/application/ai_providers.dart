import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/ai_provider_store.dart';
import '../data/http_ai_provider_client.dart';
import '../domain/ai_provider.dart';
import 'ai_preferences.dart';

final protectedAiProvidersProvider = Provider<ProtectedAiProviders>(
  (ref) => SecureAiProviders(),
);
final aiProviderStoreProvider = Provider<AiProviderStore>(
  (ref) => AiProviderStore(ref.watch(protectedAiProvidersProvider)),
);
final aiProviderClientProvider = Provider<AiProviderClient>((ref) {
  final client = HttpAiProviderClient(http.Client());
  ref.onDispose(client.close);
  return client;
});
final aiProvidersProvider =
    AsyncNotifierProvider<AiProviders, List<AiProviderConnection>>(
      AiProviders.new,
    );

class AiProviders extends AsyncNotifier<List<AiProviderConnection>> {
  @override
  Future<List<AiProviderConnection>> build() =>
      ref.read(aiProviderStoreProvider).read();

  /// Adds the connection, or replaces the saved one with the same ID.
  Future<void> save(AiProviderConnection connection) async {
    parseAiProviderBaseUrl(connection.baseUrl);
    final current = await future;
    final next = [
      for (final saved in current)
        saved.id == connection.id ? connection : saved,
      if (!current.any((saved) => saved.id == connection.id)) connection,
    ];
    await ref.read(aiProviderStoreProvider).write(next);
    state = AsyncData(next);
  }

  Future<void> remove(String id) async {
    final next = [...await future]..removeWhere((saved) => saved.id == id);
    // Routes go first: a route to a missing provider is only a clear error.
    await ref.read(aiPreferencesRepositoryProvider).removeProvider(id);
    await ref.read(aiProviderStoreProvider).write(next);
    state = AsyncData(next);
  }
}
