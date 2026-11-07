import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_cloud.dart';
import '../../ai/application/ai_lifecycle.dart';
import '../../ai/domain/ai_provider.dart';

/// Reads local readiness only; no AI request or network call starts here.
final maestarStatusProvider =
    Provider.autoDispose<({String label, bool ready})>((ref) {
      if (!ref.watch(aiEnabledProvider)) {
        return (label: 'Set up AI', ready: false);
      }
      final settings = ref.watch(aiCloudSettingsProvider).value;
      if (settings == null || !settings.configured) {
        return (label: 'Add an AI provider', ready: false);
      }
      if (ref.watch(aiKeyStatusProvider)) {
        return (label: '${settings.name} · Check your key', ready: false);
      }
      final model = settings.model(AiCapability.chat);
      return model == null
          ? (label: '${settings.name} · Choose a model', ready: false)
          : (label: '${settings.name} · $model', ready: true);
    });
