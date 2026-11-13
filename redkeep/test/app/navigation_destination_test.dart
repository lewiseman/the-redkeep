import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';

void main() {
  test(
    'Grand Maestar is addressable through gates; old AI sub-pages are not',
    () {
      for (final path in ['/settings/brain', '/settings/brain/library']) {
        expect(validatedNavigationLocation(path), path);
        final gated = navigationRedirect(
          Uri.parse(path),
          startupReady: false,
          onboardingComplete: false,
        )!;
        final welcomed = navigationRedirect(
          Uri.parse(gated),
          startupReady: true,
          onboardingComplete: false,
        )!;
        expect(
          navigationRedirect(
            Uri.parse(welcomed),
            startupReady: true,
            onboardingComplete: true,
          ),
          path,
        );
      }
      for (final path in [
        '/settings/brain/history',
        '/settings/brain/providers',
        '/settings/brain/tasks',
        '/settings/brain/voices',
        '/notes/ai-task',
        '/diary/2026-11-04/talk',
        '/settings/brain/history/short',
        '/settings/brain/history/task%2F1234',
        '/settings/brain/history/task_1234?prompt=private',
        '/settings/brain/history/task_1234/extra',
      ]) {
        expect(validatedNavigationLocation(path), '/unavailable');
      }
    },
  );
  String? redirect(
    String location, {
    bool ready = true,
    bool complete = true,
  }) => navigationRedirect(
    Uri.parse(location),
    startupReady: ready,
    onboardingComplete: complete,
  );

  test(
    'string ingress rejects malformed URIs and canonicalizes safe gates',
    () {
      expect(
        validatedNavigationLocation('https://bad:port/settings'),
        '/unavailable',
      );
      expect(
        validatedNavigationLocation('/startup?continue=%FF'),
        '/startup?continue=%2Funavailable',
      );
      expect(
        validatedNavigationLocation('/startup?continue=%2Fsettings'),
        '/startup?continue=%2Fsettings',
      );
      expect(
        validatedNavigationLocation('/settings?private=secret'),
        '/unavailable',
      );
    },
  );

  test('only canonical implemented destinations cross the boundary', () {
    for (final location in [
      '/',
      '/settings',
      '/settings/brain',
      '/%73ettings',
      '/settings/../',
    ]) {
      expect(redirect(location), isNull);
    }
    for (final location in [
      '/notes/abc',
      '/flow/a',
      '/settings/brain/unknown',
      '/settings/brain/phone',
      '/settings/brain/providers/add/Bad-Preset',
      '/tasks',
      '/settings?x=private',
      '/settings#private',
      '/settings/',
      '/SETTINGS',
      '//example.com/settings',
      'https://example.com/settings',
      'settings',
      '/settings?continue=%2F',
      '/settings%00',
    ]) {
      expect(redirect(location), '/unavailable', reason: location);
    }
  });

  test(
    'gate parameters never nest, loop or allow an external continuation',
    () {
      for (final location in [
        '/startup?continue=https%3A%2F%2Fexample.com',
        '/onboarding?continue=%2Fstartup',
        '/startup?continue=%2Fonboarding%3Fcontinue%3D%252Fsettings',
        '/startup?continue=%252Fsettings',
        '/startup?continue=%2Fsettings&continue=%2F',
        '/startup?continue=%2Fsettings&other=private',
        '/startup?continue=%2Fsettings%3Fsecret%3Dprivate',
        '/startup?continue=%2Fsettings#private',
        '/startup?continue=',
        '/startup?continue=%FF',
        '/startup?continue=%E0%A4',
        '/startup?continue=%',
        '/onboarding?',
        'https://example.com/startup?continue=%2Fsettings',
      ]) {
        expect(redirect(location), '/unavailable', reason: location);
        final pending = redirect(location, ready: false)!;
        expect(pending, '/startup?continue=%2Funavailable');
        expect(redirect(pending, ready: false), isNull);
        expect(
          redirect(pending, complete: false),
          '/onboarding?continue=%2Funavailable',
        );
      }
    },
  );

  test('each readiness combination settles within two redirects', () {
    for (final ready in [false, true]) {
      for (final complete in [false, true]) {
        for (final initial in [
          '/',
          '/settings',
          '/unavailable',
          '/missing',
          '/startup',
          '/onboarding',
        ]) {
          var location = initial;
          var count = 0;
          while (true) {
            final next = redirect(location, ready: ready, complete: complete);
            if (next == null) break;
            expect(count++, lessThan(2), reason: '$initial, $ready, $complete');
            location = next;
          }
        }
      }
    }
  });

  test('note IDs survive both gates; there is no editing address, and reject malformed input', () {
    const id = '0123456789abcdef0123456789abcdef';
    for (final path in ['/notes', '/notes/ai-search', '/notes/$id']) {
      expect(validatedNavigationLocation(path), path);
      final startup = redirect(path, ready: false)!;
      final welcome = redirect(startup, complete: false)!;
      expect(redirect(welcome), path);
    }
    for (final path in [
      '/notes/new',
      '/notes/${'A' * 32}',
      '/notes/$id/',
      '/notes/$id/edit',
      '/notes/$id/edit/extra',
      '/notes/$id?text=private',
      '/notes/$id#private',
      '/notes/%2F$id',
      '/notes/%FF',
    ]) {
      expect(validatedNavigationLocation(path), '/unavailable', reason: path);
    }
    expect(noteLocation('bad'), '/unavailable');
  });

  test(
    'canonical Diary dates, calendar, search and entry IDs survive both gates',
    () {
      const id = '0123456789abcdef0123456789abcdef';
      for (final path in [
        '/diary',
        '/diary/search',
        '/diary/calendar/2024-02-29',
        '/diary/2026-11-01/title',
        '/diary/2026-11-01/entries/$id',
        '/diary/2026-11-01/entries/$id/edit',
      ]) {
        expect(validatedNavigationLocation(path), path);
        final startup = redirect(path, ready: false)!;
        final welcome = redirect(startup, complete: false)!;
        expect(redirect(welcome), path);
      }
      for (final path in [
        // A day is reader state at /diary, not an address.
        '/diary/2026-11-01',
        '/diary/2026-02-29',
        '/diary/2026-02-29/title',
        '/diary/calendar/2026-11-01/title',
        '/diary/2026-11-01/title/extra',
        '/diary/2026-11-01/title?text=secret',
        '/diary/0000-01-01',
        '/diary/2026-11-01T00:00:00Z',
        '/diary/2026-1-01',
        '/diary/2026-11-01?text=secret',
        '/diary/2026-11-01#secret',
        '/diary/2026-11-01/entries/new',
        '/diary/2026-11-01/entries/${'A' * 32}',
        '/diary/calendar/2026-11-01/entries/$id',
        '/diary/search?keywords=secret',
        '/diary/2026-11-01/entries/$id/edit/extra',
      ]) {
        expect(validatedNavigationLocation(path), '/unavailable', reason: path);
      }
    },
  );

  test('Flow IDs and More survive both gates; malformed and future routes fail safely', () {
    const id = '0123456789abcdef0123456789abcdef';
    for (final path in [
      '/more',
      '/watchlist',
      '/flow',
      '/flow/$id',
      '/flow/$id/edit',
    ]) {
      expect(validatedNavigationLocation(path), path);
      final gate = redirect(path, ready: false)!;
      expect(redirect(redirect(gate, complete: false)!), path);
    }
    for (final path in [
      '/flow/new',
      '/flow/${'A' * 32}',
      '/flow/$id/',
      '/flow/$id/edit/extra',
      '/flow/$id?text=private',
      '/flow/$id#private',
      '/brain',
      '/more/brain',
      '/flow/%FF',
    ]) {
      expect(validatedNavigationLocation(path), '/unavailable');
    }
    expect(thoughtLocation('bad'), '/unavailable');
  });

  test(
    'settings survives local checking, downloading, onboarding and completion',
    () {
      final checking = redirect('/settings', ready: false)!;
      expect(checking, '/startup?continue=%2Fsettings');
      expect(redirect(checking, ready: false), isNull);
      final onboarding = redirect(checking, complete: false)!;
      expect(onboarding, '/onboarding?continue=%2Fsettings');
      expect(redirect(onboarding, complete: false), isNull);
      expect(redirect(onboarding), '/settings');
      expect(redirect('/onboarding'), '/');
      expect(redirect('/startup'), '/');
    },
  );
}
