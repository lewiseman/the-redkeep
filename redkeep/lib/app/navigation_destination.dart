import '../features/diary/domain/diary_period.dart';
import '../features/flow/domain/thought.dart';
import '../features/diary/domain/diary_document.dart';
import '../features/notes/domain/note_document.dart';

/// Static destinations plus validated, addressable writing and civil dates.
enum AppDestination {
  home('/'),
  settings('/settings'),
  brain('/settings/brain'),
  more('/more'),
  flow('/flow'),
  notes('/notes'),
  diary('/diary'),
  unavailable('/unavailable');

  const AppDestination(this.location);
  final String location;

  static AppDestination parse(String location) => switch (location) {
    '/' => home,
    '/settings' => settings,
    '/settings/brain' => brain,
    '/more' => more,
    '/flow' => flow,
    '/notes' => notes,
    '/diary' => diary,
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
      : destination;
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
      : destination;
  return location == requested.toString() ? null : location;
}

String _destination(String location) {
  if (AppDestination.parse(location) != AppDestination.unavailable) {
    return location;
  }
  if (const {
    '/notes/ai-search',
    '/notes/ai-task',
    '/diary/search',
    '/flow/search',
    '/settings/brain/providers',
    '/settings/brain/tasks',
    '/settings/brain/history',
    '/settings/brain/scan',
    '/settings/brain/computers',
    '/settings/brain/preferences',
    '/settings/brain/voices',
    '/settings/brain/help',
    '/settings/brain/details',
  }.contains(location)) {
    return location;
  }
  if (RegExp(
    r'^/settings/brain/(?:history|providers)/[A-Za-z0-9_-]{8,80}$|'
    r'^/settings/brain/providers/add/[a-z]{2,20}$',
  ).hasMatch(location)) {
    return location;
  }
  final diaryTitle = RegExp(r'^/diary/([a-z0-9-]+)/(?:title|talk)$')
      .firstMatch(location);
  if (diaryTitle != null && DiaryPeriod.tryParse(diaryTitle[1]!) != null) {
    return location;
  }
  final diary = RegExp(
    r'^/diary/(?:calendar/)?([a-z0-9-]+)(?:/entries/([0-9a-f]{32})(/(?:edit|photos|conversation))?)?$',
  ).firstMatch(location);
  if (diary != null &&
      DiaryPeriod.tryParse(diary[1]!) != null &&
      !(location.startsWith('/diary/calendar/') && diary[2] != null)) {
    return location;
  }
  final flow = RegExp(r'^/flow/([0-9a-f]{32})(/edit)?$').firstMatch(location);
  if (flow != null && isThoughtId(flow[1]!)) return location;
  final match = RegExp(r'^/notes/([0-9a-f]{32})(/edit)?$').firstMatch(location);
  return match != null && isNoteId(match[1]!)
      ? location
      : AppDestination.unavailable.location;
}

String noteLocation(String id, {bool edit = false}) => isNoteId(id)
    ? '/notes/$id${edit ? '/edit' : ''}'
    : AppDestination.unavailable.location;

String _requestedDestination(Uri requested) {
  final isGate =
      requested.path == '/startup' || requested.path == '/onboarding';
  if (!isGate) return _destination(requested.toString());
  if (requested.hasScheme || requested.hasAuthority || requested.hasFragment) {
    return AppDestination.unavailable.location;
  }
  if (!requested.hasQuery) return AppDestination.home.location;
  try {
    final parameters = requested.queryParametersAll;
    if (parameters.length == 1 && parameters['continue']?.length == 1) {
      return _destination(parameters['continue']!.single);
    }
  } on FormatException {
    // Malformed encoded text must still pass through startup and onboarding.
  }
  return AppDestination.unavailable.location;
}

String _gate(String path, String destination) =>
    Uri(path: path, queryParameters: {'continue': destination}).toString();

String diaryDayLocation(DiaryPeriod date) => '/diary/${date.key}';
String diaryTitleLocation(DiaryPeriod date) => '/diary/${date.key}/title';
String diaryCalendarLocation(DiaryPeriod date) => '/diary/calendar/${date.key}';
String diaryEntryLocation(DiaryPeriod date, String id, {bool edit = false}) =>
    isDiaryId(id)
    ? '/diary/${date.key}/entries/$id${edit ? '/edit' : ''}'
    : AppDestination.unavailable.location;

String thoughtLocation(String id, {bool edit = false}) => isThoughtId(id)
    ? '/flow/$id${edit ? '/edit' : ''}'
    : AppDestination.unavailable.location;
