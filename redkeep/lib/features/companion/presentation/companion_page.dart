import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai/application/ai_jobs.dart';
import '../../ai/domain/ai_operation.dart';
import '../../voice/application/phone_voice.dart';
import '../application/companion_controller.dart';
import '../data/companion_protocol.dart';
import 'ai_studio_material.dart';
import 'companion_connection_guide.dart';
import 'companion_hub_widgets.dart';
import 'companion_pairing.dart';

String companionPhaseLabel(CompanionPhase phase) => switch (phase) {
  CompanionPhase.loading => 'Reading protected trust',
  CompanionPhase.idle => 'No computer connected',
  CompanionPhase.trusted => 'Trusted · disconnected',
  CompanionPhase.connecting => 'Checking computer',
  CompanionPhase.connected => 'Connected · identity verified',
  CompanionPhase.pairing => 'Waiting for desktop approval',
  CompanionPhase.unavailable => 'Computer unavailable',
  CompanionPhase.permissionDenied => 'Local network permission needed',
  CompanionPhase.incompatible => 'Update required',
  CompanionPhase.identityChanged => 'Identity verification failed',
  CompanionPhase.revoked => 'Trust revoked or not recognized',
};
Future<void> pairCompanion(
  BuildContext context,
  WidgetRef ref, {
  bool paste = false,
  String? expectedId,
}) async {
  String? raw;
  if (paste) {
    raw = await showDialog<String>(
      context: context,
      builder: (_) => const PasteCodeDialog(),
    );
  } else {
    final scan = await context.push<CompanionScanResult>(
      '/settings/brain/scan',
    );
    if (!context.mounted) return;
    raw = scan?.useCode == true
        ? await showDialog<String>(
            context: context,
            builder: (_) => const PasteCodeDialog(),
          )
        : scan?.raw;
  }
  if (raw == null || !context.mounted) return;
  try {
    final code = PairingCode.parse(raw);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => VerifyComputerDialog(code: code),
    );
    if (!context.mounted || name == null) return;
    await ref
        .read(companionControllerProvider.notifier)
        .pair(raw, name, expectedId: expectedId);
  } on CompanionFailure catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class CompanionPage extends ConsumerStatefulWidget {
  const CompanionPage({super.key});
  @override
  ConsumerState<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends ConsumerState<CompanionPage>
    with WidgetsBindingObserver {
  GuideVoice? _voice;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_voice?.stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_voice?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      unawaited(_voice?.stop());
    }
    final connection = ref.watch(companionControllerProvider);
    final controller = ref.read(companionControllerProvider.notifier);
    final connected = connection.phase == CompanionPhase.connected;
    final computer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompanionConnectionGuide(
          connection: connection,
          onScan: () => pairCompanion(context, ref),
          onReconnect: () => connection.selected?.enabled == false
              ? controller.disconnect(resume: true)
              : controller.reconnect(),
          onCancel: controller.cancelPairing,
        ),
        if (connection.message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              connection.message!,
              key: const ValueKey('companion-message'),
            ),
          ),
        if (connected)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CompanionReadinessStrip(state: connection),
          ),
        if (connection.computers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CompanionComputerCard(
              state: connection,
              onTap: () => context.push('/settings/brain/computers'),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              key: const ValueKey('companion-paste'),
              onPressed: connection.busy
                  ? null
                  : () => pairCompanion(context, ref, paste: true),
              icon: const Icon(Icons.content_paste),
              label: const Text('Use a code'),
            ),
            TextButton.icon(
              key: const ValueKey('companion-discover'),
              onPressed: connection.busy || connection.scanning
                  ? null
                  : () {
                      unawaited(controller.discover());
                      context.push('/settings/brain/computers');
                    },
              icon: const Icon(Icons.radar),
              label: const Text('Find computer'),
            ),
            TextButton.icon(
              onPressed: () async {
                _voice = ref.read(guideVoiceProvider);
                try {
                  await _voice!.speak(
                    'Put your phone and computer on the same Wi-Fi. Open Journal Companion on the computer and choose Connect a phone. Scan its QR code. Compare every character of the phone code on both devices, then approve on the computer.',
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'An offline setup voice is unavailable. Choose a voice in Voices.',
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Hear setup guide'),
            ),
          ],
        ),
      ],
    );
    return CompanionDetailLayout(
      title: 'Grand Maestar',
      children: [
        const CompanionDetailHeading(
          icon: Icons.auto_awesome_outlined,
          title: 'Your AI, your choice',
          description: 'Use your own computer or an AI provider, task by task.',
        ),
        const AiStudioSectionHeading(label: 'Writing AI'),
        AiStudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                key: const ValueKey('ai-providers-link'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('AI providers'),
                subtitle: const Text('Connect a provider with your own token.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  unawaited(_voice?.stop());
                  context.push('/settings/brain/providers');
                },
              ),
              ListTile(
                key: const ValueKey('ai-tasks-link'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('Tasks'),
                subtitle: const Text('Choose what runs each writing task.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  unawaited(_voice?.stop());
                  context.push('/settings/brain/tasks');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => context.push('/settings/brain/history'),
          icon: const Icon(Icons.history_rounded),
          label: const Text('AI task history'),
        ),
        const AiTaskPanel(),
        const AiStudioSectionHeading(label: 'Your computer'),
        computer,
        const AiStudioSectionHeading(label: 'Preferences'),
        CompanionShortcuts(
          onVoice: () {
            unawaited(_voice?.stop());
            context.push('/settings/brain/voices');
          },
          onPreferences: () {
            unawaited(_voice?.stop());
            context.push('/settings/brain/preferences');
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => context.push('/settings/brain/help'),
              child: const Text('Need help?'),
            ),
            TextButton(
              onPressed: () => context.push('/settings/brain/details'),
              child: const Text('Connection details'),
            ),
          ],
        ),
      ],
    );
  }
}

class AiTaskPanel extends ConsumerWidget {
  const AiTaskPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiJobsProvider);
    final job = state.job;
    if (job == null && state.message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AiStudioCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (job != null)
              Text(
                '${job.operation.label} · ${job.phase} · ${job.destinationLabel}',
              ),
            if (state.message != null) Text(state.message!),
            if (job?.operation.isNote == true)
              TextButton(
                onPressed: () => context.push('/notes/ai-task'),
                child: const Text('Review note task'),
              ),
            if (job?.operation == AiOperation.diaryDetails &&
                job?.phase == 'completed')
              TextButton(
                onPressed: () => context.push('/diary/${job!.key}/title'),
                child: const Text('Review day suggestions'),
              ),
            Wrap(
              spacing: 8,
              children: [
                if (!state.busy)
                  TextButton(
                    onPressed: ref.read(aiJobsProvider.notifier).retry,
                    child: const Text('Retry / retrieve'),
                  ),
                if (job != null && !job.terminal)
                  TextButton(
                    onPressed: ref.read(aiJobsProvider.notifier).cancel,
                    child: const Text('Cancel task'),
                  ),
                if (job?.terminal == true)
                  TextButton(
                    onPressed: ref.read(aiJobsProvider.notifier).clear,
                    child: const Text('Clear task'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
