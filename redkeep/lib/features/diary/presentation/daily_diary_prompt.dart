import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_lifecycle.dart';
import '../../ai/application/ai_preferences.dart';
import '../application/daily_question_controller.dart';
import '../application/diary_providers.dart';
import '../domain/civil_date.dart';
import 'diary_writing_prompt.dart';

class DailyDiaryPrompt extends ConsumerStatefulWidget {
  const DailyDiaryPrompt({
    super.key,
    required this.date,
    required this.onWrite,
    required this.active,
  });
  final CivilDate date;
  final VoidCallback onWrite;
  final bool active;
  @override
  ConsumerState<DailyDiaryPrompt> createState() => _DailyDiaryPromptState();
}

class _DailyDiaryPromptState extends ConsumerState<DailyDiaryPrompt> {
  DailyQuestionController? _controller;
  Timer? _midnight;

  void _watchMidnight() {
    _midnight?.cancel();
    if (!widget.active || !ref.read(aiEnabledProvider)) return;
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
    final today = CivilDate.fromComponents(ref.watch(diaryClockProvider)());
    if (!ref.watch(aiEnabledProvider) ||
        !widget.active ||
        today != widget.date ||
        ref.watch(aiPreferencesProvider).value?.dailyQuestions != true) {
      _controller?.activate(false);
      return DiaryWritingPrompt(onTap: widget.onWrite);
    }
    final provider = dailyQuestionProvider(widget.date);
    final value = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    _controller = controller;
    final active =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.activate(active);
    });
    final question = value.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiaryWritingPrompt(onTap: widget.onWrite, text: question?.text),
        if (question != null)
          Text(
            question.grounded
                ? 'Following up on ${question.ago == 0
                      ? 'today’s writing'
                      : question.ago == 1
                      ? 'yesterday’s writing'
                      : 'writing from ${question.ago} days ago'}.'
                : 'A general question to help you start.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (value.message != null)
          Text(value.message!, style: Theme.of(context).textTheme.bodySmall),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: value.busy ? null : () => controller.request(),
              child: Text(
                value.busy
                    ? 'Thinking…'
                    : question == null
                    ? 'Ask for a question'
                    : 'Another question',
              ),
            ),
            if (question != null)
              TextButton(
                onPressed: value.busy ? null : controller.skip,
                child: const Text('Skip'),
              ),
          ],
        ),
      ],
    );
  }
}
