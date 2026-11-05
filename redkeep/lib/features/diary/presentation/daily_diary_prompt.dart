import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_lifecycle.dart';
import '../../ai/application/ai_preferences.dart';
import '../application/daily_question_controller.dart';
import '../application/diary_providers.dart';
import '../domain/diary_period.dart';
import 'diary_writing_prompt.dart';

class DailyDiaryPrompt extends ConsumerStatefulWidget {
  const DailyDiaryPrompt({
    super.key,
    required this.date,
    required this.onWrite,
    required this.active,
  });
  final DiaryPeriod date;

  /// Opens the editor, with today's question once one is ready.
  final ValueChanged<String?> onWrite;

  /// Only the live reader owns question generation and activation. Static
  /// paper faces still mirror its question.
  final bool active;
  @override
  ConsumerState<DailyDiaryPrompt> createState() => _DailyDiaryPromptState();
}

class _DailyDiaryPromptState extends ConsumerState<DailyDiaryPrompt> {
  DailyQuestionController? _controller;
  Timer? _midnight;

  void _watchMidnight() {
    _midnight?.cancel();
    if (!widget.date.isDay || !widget.active || !ref.read(aiEnabledProvider)) {
      return;
    }
    final now = ref.read(diaryClockProvider)();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () {
      if (!mounted) return;
      unawaited(_controller?.refresh());
      setState(() {});
    });
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _controller?.activate(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _watchMidnight();
    final today = ref.watch(diaryClockProvider)();
    if (!widget.date.isDay ||
        !ref.watch(aiEnabledProvider) ||
        !widget.date.isCurrent(today) ||
        ref.watch(aiPreferencesProvider).value?.dailyQuestions != true) {
      _controller?.activate(false);
      _controller = null;
      return DiaryWritingPrompt(onTap: () => widget.onWrite(null));
    }
    final provider = dailyQuestionProvider(widget.date);
    final value = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    // A preview observes the same state without activating or deactivating the
    // shared controller. Otherwise its rebuild/disposal can stop the reader.
    final owner = widget.active ? controller : null;
    if (_controller != owner) {
      _controller?.activate(false);
      _controller = owner;
    }
    if (widget.active) {
      final active =
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.of(context)?.isCurrent ?? true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active && identical(_controller, controller)) {
          controller.activate(active);
        }
      });
    }
    final question = value.question?.text;
    return DiaryWritingPrompt(
      onTap: () => widget.onWrite(question),
      text: question,
    );
  }
}
