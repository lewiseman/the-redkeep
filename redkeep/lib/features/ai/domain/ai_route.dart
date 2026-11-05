/// Where one AI task runs. There is deliberately no fallback between routes.
class AiRoute {
  const AiRoute.companion() : providerId = null, model = null;
  const AiRoute.provider(String this.providerId, String this.model);

  final String? providerId, model;
  bool get isCompanion => providerId == null;

  Map<String, String> toJson() => isCompanion
      ? const {'kind': 'companion'}
      : {'kind': 'provider', 'provider': providerId!, 'model': model!};

  /// Returns null for anything unrecognized, so stale data never blocks reads.
  static AiRoute? tryParse(Object? value) {
    if (value is! Map) return null;
    if (value['kind'] == 'companion') return const AiRoute.companion();
    final provider = value['provider'], model = value['model'];
    if (value['kind'] != 'provider' ||
        provider is! String ||
        model is! String ||
        provider.isEmpty ||
        model.isEmpty) {
      return null;
    }
    return AiRoute.provider(provider, model);
  }

  @override
  bool operator ==(Object other) =>
      other is AiRoute &&
      other.providerId == providerId &&
      other.model == model;
  @override
  int get hashCode => Object.hash(providerId, model);
}
