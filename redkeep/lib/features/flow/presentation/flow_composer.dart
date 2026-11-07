import 'package:flutter/material.dart';

import '../../../core/presentation/rendering_policy.dart';

/// Flow's full-width input. Send appears inside the pill once there is text.
class FlowComposer extends StatelessWidget {
  const FlowComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onChanged,
    this.onMicrophone,
    this.microphone = true,
    this.enabled = true,
    this.saving = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback? onMicrophone;

  /// False when the AI provider has no speech-to-text.
  final bool microphone;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final duration = RenderingPolicyScope.of(context).reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: RenderingPolicyScope.of(context).simplerEffects ? 0 : 8,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .14),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                child: Semantics(
                  label: 'New thought',
                  child: TextField(
                    key: const ValueKey('flow-body'),
                    controller: controller,
                    enabled: enabled,
                    onChanged: onChanged,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 4,
                    keyboardAppearance: Theme.of(context).brightness,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    scrollPadding: EdgeInsets.zero,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'What’s on your mind?',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant
                            .withValues(alpha: .7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (microphone)
              IconButton(
                key: const ValueKey('flow-microphone'),
                tooltip: 'Capture a thought by voice',
                onPressed: enabled ? onMicrophone : null,
                icon: const Icon(Icons.mic_none_rounded),
              ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                // Plain swap: the composer sits in a measured scroll view, where
                // a size animation would re-lay itself out mid-layout.
                return AnimatedSwitcher(
                  duration: duration,
                  child: !hasText
                      ? const SizedBox(
                          key: ValueKey(false),
                          width: 12,
                          height: 56,
                        )
                      : Padding(
                          key: const ValueKey(true),
                          padding: const EdgeInsets.all(6),
                          child: IconButton.filled(
                            tooltip: saving ? 'Saving…' : 'Add thought',
                            onPressed: enabled ? onSend : null,
                            style: IconButton.styleFrom(
                              fixedSize: const Size(44, 44),
                              minimumSize: const Size(44, 44),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onPrimary,
                            ),
                            icon: saving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 20),
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
