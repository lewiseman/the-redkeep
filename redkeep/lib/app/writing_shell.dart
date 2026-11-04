import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bottom_navbar.dart';

class WritingShell extends StatelessWidget {
  const WritingShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  static const _paths = ['/diary', '/notes', '/flow', '/more'];

  @override
  Widget build(BuildContext context) {
    final selected = location.startsWith('/notes')
        ? 1
        : location.startsWith('/flow')
        ? 2
        : location == '/more' || location.startsWith('/settings')
        ? 3
        : 0;
    final focusedDiary =
        location == '/diary/search' ||
        location.startsWith('/diary/calendar/') ||
        (location.startsWith('/diary/') &&
            (location.endsWith('/title') || location.endsWith('/talk'))) ||
        (location.startsWith('/diary/') && location.contains('/entries/'));
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar:
          focusedDiary ||
              location.startsWith('/notes/') ||
              MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : RedkeepBottomNavbar(
              selectedIndex: selected,
              onSelected: (index) => context.go(_paths[index]),
            ),
    );
  }
}
