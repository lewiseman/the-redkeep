import 'package:flutter/material.dart';

/// The legacy lavender pill, with native focus/tap semantics and a flat mode.
class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.simple,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool simple;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    child: Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: simple ? const Color(0xFFB4A5BB) : null,
        gradient: simple
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFB4A5BB),
                  Color(0xFFC4B8CA),
                  Color(0xFFA89582),
                ],
              ),
        boxShadow: simple
            ? null
            : const [
                BoxShadow(
                  color: Color(0x2165503B),
                  blurRadius: 18,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: simple ? const Color(0xFFE6E0F8) : null,
          gradient: simple
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFAF8FF), Color(0xFFDFDAFF)],
                ),
          border: Border.all(color: Colors.white.withValues(alpha: .65)),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: const Color(0xFF161658).withValues(alpha: .18),
            highlightColor: const Color(0xFF161658).withValues(alpha: .08),
            hoverColor: const Color(0xFF161658).withValues(alpha: .06),
            focusColor: const Color(0xFF161658).withValues(alpha: .12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  const SizedBox(width: 36),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF161658),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .1,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF161658).withValues(alpha: .08),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF161658),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
