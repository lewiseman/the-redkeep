import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// All currently implemented destinations, with wrapping labels at large text.
class WritingShell extends StatelessWidget {
  const WritingShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  @override
  Widget build(BuildContext context) {
    final selected = location.startsWith('/notes')
        ? '/notes'
        : location.startsWith('/flow')
        ? '/flow'
        : location == '/more' || location == '/settings'
        ? '/more'
        : '/diary';
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    for (final destination in const [
                      ('/diary', 'Diary'),
                      ('/notes', 'Notes'),
                      ('/flow', 'Flow'),
                      ('/more', 'More'),
                    ])
                      Semantics(
                        selected: selected == destination.$1,
                        child: TextButton(
                          onPressed: () => context.go(destination.$1),
                          style: selected == destination.$1
                              ? TextButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                )
                              : null,
                          child: Text(destination.$2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
