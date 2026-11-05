import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai/application/ai_jobs.dart';
import '../../ai/application/ai_preferences.dart';
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
    final prefs = ref.watch(aiPreferencesProvider);
    final repository = ref.read(aiPreferencesRepositoryProvider);
    final controller = ref.read(companionControllerProvider.notifier);
    final mode = prefs.value?.mode ?? AiMode.auto;
    final connected = connection.phase == CompanionPhase.connected;
    final phoneFirst =
        mode == AiMode.device || mode == AiMode.auto && !connected;
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
    final phone = AiStudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('AI on this phone', style: studioTitle(context, size: 21)),
          const Text(
            'Use Redkeep’s existing phone models for writing while away. Search by meaning still needs the computer.',
          ),
          TextButton.icon(
            onPressed: () {
              unawaited(_voice?.stop());
              context.push('/settings/brain/phone');
            },
            icon: const Icon(Icons.phone_android),
            label: const Text('Manage phone models'),
          ),
        ],
      ),
    );
    return CompanionDetailLayout(
      title: 'Grand Maestar',
      children: [
        const CompanionDetailHeading(
          icon: Icons.auto_awesome_outlined,
          title: 'Your AI, on your devices',
          description: 'Choose where AI runs and manage your setup.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in AiMode.values)
              ChoiceChip(
                key: ValueKey('ai-mode-${choice.name}'),
                label: Text(switch (choice) {
                  AiMode.auto => 'Auto',
                  AiMode.companion => 'Computer',
                  AiMode.device => 'Phone',
                }),
                selected: mode == choice,
                onSelected: prefs.hasValue
                    ? (_) async {
                        try {
                          await repository.mode(choice);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not save your AI mode.'),
                              ),
                            );
                          }
                        }
                      }
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (mode == AiMode.auto)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              connected
                  ? 'Auto uses your connected computer for new requests.'
                  : 'Auto uses assigned phone models while your computer is away.',
            ),
          ),
        TextButton.icon(
          onPressed: () => context.push('/settings/brain/history'),
          icon: const Icon(Icons.history_rounded),
          label: const Text('AI task history'),
        ),
        const AiTaskPanel(),
        const AiStudioSectionHeading(label: 'Setup'),
        if (phoneFirst) phone else computer,
        const SizedBox(height: 16),
        ExpansionTile(
          title: Text(
            phoneFirst ? 'Connect your computer' : 'Take AI with you',
          ),
          children: [phoneFirst ? computer : phone],
        ),
        ExpansionTile(
          title: const Text('Advanced'),
          subtitle: const Text(
            'Choose a destination for individual diary operations',
          ),
          children: [
            for (final operation in AiOperation.values.where(
              (o) => o.supportsPhone,
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: DropdownButtonFormField<AiMode>(
                  key: ValueKey(
                    'ai-override-${operation.name}-${prefs.value?.overrides[operation]}',
                  ),
                  initialValue:
                      prefs.value?.overrides[operation] ?? AiMode.auto,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(labelText: operation.label),
                  items: const [
                    DropdownMenuItem(
                      value: AiMode.auto,
                      child: Text('Follow choice above'),
                    ),
                    DropdownMenuItem(
                      value: AiMode.companion,
                      child: Text('Computer'),
                    ),
                    DropdownMenuItem(
                      value: AiMode.device,
                      child: Text('Phone'),
                    ),
                  ],
                  onChanged: prefs.hasValue
                      ? (value) async {
                          if (value != null) {
                            await repository.override(operation, value);
                          }
                        }
                      : null,
                ),
              ),
          ],
        ),
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
                '${job.operation.label} · ${job.phase} · ${job.provider == 'companion' ? 'Computer' : 'Phone'}',
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
