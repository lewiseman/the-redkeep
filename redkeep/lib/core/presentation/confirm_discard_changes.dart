import 'package:flutter/material.dart';

Future<bool> confirmDiscardChanges(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Discard changes?'),
              const Text('Unsaved writing will be removed.'),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep writing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ),
      ),
    ) ??
    false;
