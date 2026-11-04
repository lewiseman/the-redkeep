import '../../ai/application/ai_lifecycle.dart';
import '../../ai/application/ai_preferences.dart';
import '../../ai/domain/ai_operation.dart';
import '../../companion/application/companion_controller.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/application/brain_controller.dart';
import '../../brain/application/brain_providers.dart';
import '../../brain/domain/brain.dart';

/// Reads local readiness only; neither inference nor downloads start here.
final maestarStatusProvider =
    Provider.autoDispose<({String label, bool ready})>((ref) {
      if (ref.watch(aiEnabledProvider)) {
        final connection = ref.watch(companionControllerProvider);
        final mode =
            ref.watch(aiPreferencesProvider).value?.mode ?? AiMode.auto;
        if (mode != AiMode.device &&
            connection.phase == CompanionPhase.connected) {
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
        }
        if (mode == AiMode.companion) {
          return (label: 'Connect your computer', ready: false);
        }
      }
      final state = ref.watch(brainControllerProvider);
      if (state.busy) {
        return (
          label: state.operation ?? 'Checking model files…',
          ready: false,
        );
      }
      if (state.failure != null) {
        return (label: 'Needs attention', ready: false);
      }
      if (!state.loaded) {
        return (label: 'Checking model files…', ready: false);
      }
      final catalog = ref.watch(brainCatalogProvider);
      final ready = catalog.any(
        (model) =>
            state.files[model.id] == ModelFileState.available &&
            state.assignments.entries.any(
              (assignment) =>
                  assignment.value == model.id &&
                  model.capabilities.contains(assignment.key),
            ),
      );
      return (
        label: ready ? 'Ready on this device' : 'Set up on-device AI',
        ready: ready,
      );
    });
