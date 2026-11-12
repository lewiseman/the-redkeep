import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/diary/domain/diary_period.dart';
import '../features/flow/domain/thought.dart';
import '../features/diary/domain/diary_document.dart';
import '../features/notes/domain/note_document.dart';

final initialNavigationLocationProvider = Provider<String>(
  (ref) => WidgetsBinding.instance.platformDispatcher.defaultRouteName,
);

/// Static destinations plus validated, addressable writing and civil dates.
enum AppDestination {
  home('/'),
  settings('/settings'),
  brain('/settings/brain'),
  library('/settings/brain/library'),
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
    '/settings/brain/library' => library,
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
    '/diary/search',
    '/flow/search',
  }.contains(location)) {
    return location;
  }
  final diaryTitle = RegExp(r'^/diary/([a-z0-9-]+)/title$')
      .firstMatch(location);
  if (diaryTitle != null && DiaryPeriod.tryParse(diaryTitle[1]!) != null) {
    return location;
  }
  // A diary day itself is reader state at /diary, never an address.
  final diary = RegExp(
    r'^/diary/(?:calendar/([a-z0-9-]+)|([a-z0-9-]+)/entries/[0-9a-f]{32}(?:/(?:edit|photos))?)$',
  ).firstMatch(location);
  if (diary != null && DiaryPeriod.tryParse((diary[1] ?? diary[2])!) != null) {
    return location;
  }
  final flow = RegExp(r'^/flow/([0-9a-f]{32})(/edit)?$').firstMatch(location);
  if (flow != null && isThoughtId(flow[1]!)) return location;
  final match = RegExp(r'^/notes/([0-9a-f]{32})(?:/website|/scan|/maester)?$')
      .firstMatch(location);
  return match != null && isNoteId(match[1]!)
      ? location
      : AppDestination.unavailable.location;
}

/// Reading and editing are states of the same note page, so there is no
/// separate editing address. New notes open in editing on their own.
String noteLocation(String id) =>
    isNoteId(id) ? '/notes/$id' : AppDestination.unavailable.location;

/// A note's generated website, shown on a page of its own.
String noteWebsiteLocation(String id) =>
    isNoteId(id) ? '/notes/$id/website' : AppDestination.unavailable.location;

/// The note's conversation with the Maester, on a page of its own.
String noteChatLocation(String id) =>
    isNoteId(id) ? '/notes/$id/maester' : AppDestination.unavailable.location;

/// Scanning a page into a note, on a page of its own.
String noteScanLocation(String id) =>
    isNoteId(id) ? '/notes/$id/scan' : AppDestination.unavailable.location;

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

String diaryTitleLocation(DiaryPeriod date) => '/diary/${date.key}/title';
String diaryCalendarLocation(DiaryPeriod date) => '/diary/calendar/${date.key}';
String diaryEntryLocation(DiaryPeriod date, String id, {bool edit = false}) =>
    isDiaryId(id)
    ? '/diary/${date.key}/entries/$id${edit ? '/edit' : ''}'
    : AppDestination.unavailable.location;

String thoughtLocation(String id, {bool edit = false}) => isThoughtId(id)
    ? '/flow/$id${edit ? '/edit' : ''}'
    : AppDestination.unavailable.location;
