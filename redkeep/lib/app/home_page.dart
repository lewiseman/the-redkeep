import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/paper_surface.dart';
import 'app_shell.dart';
import 'navigation_destination.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: PaperSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome to Redkeep',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'A quiet space for your words.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.go(AppDestination.settings.location),
              icon: const Icon(Icons.tune),
              label: const Text('Appearance'),
            ),
          ],
        ),
      ),
    );
  }
}
