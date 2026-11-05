import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_lifecycle.dart';
import '../../ai/application/ai_preferences.dart';
import '../../ai/application/ai_providers.dart';
import '../../companion/application/companion_controller.dart';

/// Reads local readiness only; no AI task or network request starts here.
final maestarStatusProvider =
    Provider.autoDispose<({String label, bool ready})>((ref) {
      if (!ref.watch(aiEnabledProvider)) {
        return (label: 'Set up AI', ready: false);
      }
      final route = ref.watch(aiPreferencesProvider).value?.defaultRoute;
      if (route != null && !route.isCompanion) {
        final provider = ref
            .watch(aiProvidersProvider)
            .value
            ?.where((p) => p.id == route.providerId)
            .firstOrNull;
        return provider == null
            ? (label: 'Choose a provider', ready: false)
            : (label: '${provider.name} · ${route.model}', ready: true);
      }
      final connection = ref.watch(companionControllerProvider);
      if (connection.phase != CompanionPhase.connected) {
        return (label: 'Connect a computer or add a provider', ready: false);
      }
      final writing = (connection.status?['capabilities'] as List? ?? [])
          .whereType<Map>()
          .where((c) => c['id'] == 'text')
          .firstOrNull;
      return (
        label: writing?['status'] == 'ready'
            ? 'Computer connected · Writing ready'
            : 'Computer connected · Check models',
        ready: writing?['status'] == 'ready',
      );
    });
