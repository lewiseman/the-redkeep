/// Only implemented, parameter-free destinations cross the navigation boundary.
/// Add entity validation here when a real entity screen is introduced.
enum AppDestination {
  home('/'),
  settings('/settings'),
  unavailable('/unavailable');

  const AppDestination(this.location);
  final String location;

  static AppDestination parse(String location) => switch (location) {
    '/' => home,
    '/settings' => settings,
    _ => unavailable,
  };
}

/// Use for untrusted strings before calling go_router. Platform initial and
/// subsequent route information also passes through this boundary.
String validatedNavigationLocation(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null) return AppDestination.unavailable.location;
  final destination = _requestedDestination(uri);
  final isGate = uri.path == '/startup' || uri.path == '/onboarding';
  return isGate && !uri.hasScheme && !uri.hasAuthority && !uri.hasFragment
      ? _gate(uri.path, destination)
      : destination.location;
}

/// Pure routing policy. Gate URIs carry only a canonical, validated destination;
/// they cannot nest gates, retain arbitrary URL content, or redirect off-app.
String? navigationRedirect(
  Uri requested, {
  required bool startupReady,
  required bool onboardingComplete,
}) {
  final destination = _requestedDestination(requested);
  final location = !startupReady
      ? _gate('/startup', destination)
      : !onboardingComplete
      ? _gate('/onboarding', destination)
      : destination.location;
  return location == requested.toString() ? null : location;
}

AppDestination _requestedDestination(Uri requested) {
  final isGate =
      requested.path == '/startup' || requested.path == '/onboarding';
  if (!isGate) return AppDestination.parse(requested.toString());
  if (requested.hasScheme || requested.hasAuthority || requested.hasFragment) {
    return AppDestination.unavailable;
  }
  if (!requested.hasQuery) return AppDestination.home;
  try {
    final parameters = requested.queryParametersAll;
    if (parameters.length == 1 && parameters['continue']?.length == 1) {
      return AppDestination.parse(parameters['continue']!.single);
    }
  } on FormatException {
    // Malformed encoded text must still pass through startup and onboarding.
  }
  return AppDestination.unavailable;
}

String _gate(String path, AppDestination destination) => Uri(
  path: path,
  queryParameters: {'continue': destination.location},
).toString();
