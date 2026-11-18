import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../../diary/application/diary_providers.dart';
import '../../diary/application/diary_reader_day.dart';
import '../../diary/domain/diary_period.dart';
import '../../notes/application/notes_providers.dart';

/// What a home screen widget tap asks for. Each opens a real page and
/// replaces this one, so it never stays in history.
sealed class HomeWidgetLaunch {
  const HomeWidgetLaunch();
}

/// A new entry for today, open in the editor.
class WriteTodayLaunch extends HomeWidgetLaunch {
  const WriteTodayLaunch();
}

/// The diary reader turned to [date]; today when null.
class DiaryDayLaunch extends HomeWidgetLaunch {
  const DiaryDayLaunch([this.date]);
  final DiaryPeriod? date;
}

/// A new note, open in editing.
class NewNoteLaunch extends HomeWidgetLaunch {
  const NewNoteLaunch();
}

class HomeWidgetLaunchPage extends ConsumerStatefulWidget {
  const HomeWidgetLaunchPage({super.key, required this.launch});
  final HomeWidgetLaunch launch;

  @override
  ConsumerState<HomeWidgetLaunchPage> createState() =>
      _HomeWidgetLaunchPageState();
}

class _HomeWidgetLaunchPageState extends ConsumerState<HomeWidgetLaunchPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    String location;
    try {
      location = switch (widget.launch) {
        WriteTodayLaunch() => await _writeToday(),
        DiaryDayLaunch(:final date) => _showDay(date),
        NewNoteLaunch() => await _newNote(),
      };
    } catch (_) {
      location = AppDestination.diary.location;
    }
    if (mounted) context.go(location);
  }

  Future<String> _writeToday() async {
    final today = DiaryPeriod.fromComponents(ref.read(diaryClockProvider)());
    ref.read(diaryReaderDayProvider.notifier).showToday();
    final id = await ref.read(diaryActionsProvider.notifier).create(today);
    return diaryEntryLocation(today, id, edit: true);
  }

  String _showDay(DiaryPeriod? date) {
    final reader = ref.read(diaryReaderDayProvider.notifier);
    final today = DiaryPeriod.fromComponents(ref.read(diaryClockProvider)());
    date == null || date == today ? reader.showToday() : reader.show(date);
    return AppDestination.diary.location;
  }

  Future<String> _newNote() async {
    final id = await ref.read(notesActionsProvider.notifier).create();
    return id == null ? AppDestination.notes.location : noteLocation(id);
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
