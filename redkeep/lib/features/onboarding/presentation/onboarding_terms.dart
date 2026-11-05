import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Redkeep's legal pages in an external browser.
final onboardingLegalLinkLauncherProvider =
    Provider<Future<bool> Function(Uri)>(
      (ref) =>
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );

class OnboardingTerms extends ConsumerStatefulWidget {
  const OnboardingTerms({super.key});
  @override
  ConsumerState<OnboardingTerms> createState() => _OnboardingTermsState();
}

class _OnboardingTermsState extends ConsumerState<OnboardingTerms> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () =>
        unawaited(_open('https://redkeep.lewiseman.com/terms.html'));
  late final _privacy = TapGestureRecognizer()
    ..onTap = () =>
        unawaited(_open('https://redkeep.lewiseman.com/privacy.html'));

  Future<void> _open(String url) async {
    try {
      if (await ref.read(onboardingLegalLinkLauncherProvider)(Uri.parse(url))) {
        return;
      }
    } catch (_) {
      /* Platform errors never become user-facing details. */
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open this page. Please try again.'),
      ),
    );
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('onboarding-terms'),
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text.rich(
          TextSpan(
            text: 'By continuing. You agree to our ',
            style: const TextStyle(
              color: Color(0xFF6B5E70),
              fontSize: 14,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: 'Terms',
                recognizer: _terms,
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF6B5E70),
                ),
              ),
              const TextSpan(text: " and you've read the "),
              TextSpan(
                text: 'Privacy policy',
                recognizer: _privacy,
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF6B5E70),
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
