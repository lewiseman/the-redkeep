import 'ai_operation.dart';
import 'ai_route.dart';

class AiPreferences {
  const AiPreferences({
    this.defaultRoute = const AiRoute.companion(),
    this.overrides = const {},
    this.dailyQuestionOptIn,
    this.dailyQuestions = true,
    this.collections = const {'note', 'diary', 'thought'},
    this.paused = false,
    this.voice,
  });
  final AiRoute defaultRoute;
  final Map<AiOperation, AiRoute> overrides;

  /// The one provider allowed to receive diary text without a tap.
  final String? dailyQuestionOptIn;
  final bool dailyQuestions, paused;
  final Set<String> collections;
  final Map<String, String>? voice;

  AiRoute routeFor(AiOperation operation) => operation.supportsProvider
      ? overrides[operation] ?? defaultRoute
      : const AiRoute.companion();

  /// Companion runs stay automatic. A provider needs its own explicit opt-in.
  bool get dailyQuestionMayRunAutomatically {
    final route = routeFor(AiOperation.dailyQuestion);
    return route.isCompanion || route.providerId == dailyQuestionOptIn;
  }
}
