import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/paper_surface.dart';
import 'app_shell.dart';

class RouteNotFoundPage extends StatelessWidget {
  const RouteNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: PaperSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'This page is unavailable.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Return home'),
            ),
          ],
        ),
      ),
    );
  }
}
