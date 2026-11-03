import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, this.floatingActionButton});

  final Widget child;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Redkeep')),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              floatingActionButton == null ? 24 : 96,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
