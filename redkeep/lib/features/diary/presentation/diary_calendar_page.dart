import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation_destination.dart';
import '../application/diary_providers.dart';
import '../domain/civil_date.dart';
import 'diary_widgets.dart';

class DiaryCalendarPage extends ConsumerStatefulWidget {
  const DiaryCalendarPage({super.key, this.selected});
  final CivilDate? selected;
  @override
  ConsumerState<DiaryCalendarPage> createState() => _DiaryCalendarPageState();
}

class _DiaryCalendarPageState extends ConsumerState<DiaryCalendarPage> {
  late final CivilDate selected =
      widget.selected ??
      CivilDate.fromComponents(ref.read(diaryClockProvider)());
  @override
  Widget build(BuildContext context) {
    final first = CivilDate(selected.year, selected.month, 1);
    final before = first.shift(-1);
    final after = first.shift(first.daysInMonth);
    final large =
        MediaQuery.textScalerOf(context).scale(14) > 20 ||
        MediaQuery.sizeOf(context).width < 400;
    final days = List.generate(
      first.daysInMonth,
      (i) => CivilDate(first.year, first.month, i + 1),
    );
    return DiaryFrame(
      slivers: [
        diaryBlock(
          NotebookSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'My diary',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(
                  'A notebook for each day. Your words stay on this device.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => context.go(
                        diaryDayLocation(
                          CivilDate.fromComponents(
                            ref.read(diaryClockProvider)(),
                          ),
                        ),
                      ),
                      child: const Text('Open today'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/diary/search'),
                      child: const Text('Search diary'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        diaryBlock(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${first.key.substring(0, 7)} calendar',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: before == null
                        ? null
                        : () => context.go(diaryCalendarLocation(before)),
                    child: const Text('Previous month'),
                  ),
                  OutlinedButton(
                    onPressed: after == null
                        ? null
                        : () => context.go(diaryCalendarLocation(after)),
                    child: const Text('Next month'),
                  ),
                ],
              ),
              const Text(
                'Choose a date to read or write. Empty days are welcome.',
              ),
            ],
          ),
        ),
        if (large)
          SliverList.builder(
            itemCount: days.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(days[index].key),
              selected: days[index] == selected,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(diaryDayLocation(days[index])),
            ),
          )
        else ...[
          diaryBlock(
            Row(
              children: [
                for (final label in [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ])
                  Expanded(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 56,
              ),
              itemCount: first.weekday - 1 + days.length,
              itemBuilder: (context, index) {
                final dayIndex = index - first.weekday + 1;
                if (dayIndex < 0) return const SizedBox.shrink();
                final date = days[dayIndex];
                return Semantics(
                  label: date.key,
                  button: true,
                  onTap: () => context.go(diaryDayLocation(date)),
                  selected: date == selected,
                  child: ExcludeSemantics(
                    child: TextButton(
                      onPressed: () => context.go(diaryDayLocation(date)),
                      child: Text('${date.day}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
