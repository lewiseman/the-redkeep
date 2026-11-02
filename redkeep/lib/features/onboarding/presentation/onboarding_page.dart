import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../core/presentation/paper_surface.dart';
import '../application/onboarding_controller.dart';

class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    return AppShell(
      child: PaperSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Make yourself at home',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text('Welcome to Redkeep, a quiet space for your words.'),
            const SizedBox(height: 16),
            const Text(
              'Choose a light or dark appearance, reduce motion, or simplify paper effects in Appearance. Your device’s motion settings are always respected.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Your settings and downloaded artwork stay on this device. Once the required artwork is ready, Redkeep can open offline.',
            ),
            const SizedBox(height: 24),
            if (state.saveFailed) ...[
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Setup could not be saved. Check device storage and try again.',
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: state.complete == false && !state.saving
                  ? ref.read(onboardingControllerProvider.notifier).complete
                  : null,
              child: Text(
                state.saving
                    ? 'Saving…'
                    : state.saveFailed
                    ? 'Try again'
                    : 'Enter Redkeep',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
