import '../../../core/presentation/confirm_discard_changes.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_shell.dart';
import '../application/flow_editor_controller.dart';
import 'flow_editor.dart';

class ThoughtEditPage extends ConsumerWidget {
  const ThoughtEditPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(flowEditorProvider(id)).value;
    return PopScope(
      canPop: state == null || !state.saving && !state.changed,
      onPopInvokedWithResult: (popped, _) async {
        if (popped || state == null || state.saving) return;
        if (await confirmDiscardChanges(context)) {
          await ref.read(flowEditorProvider(id).notifier).discard();
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: AppShell(child: FlowEditor(id: id)),
    );
  }
}
