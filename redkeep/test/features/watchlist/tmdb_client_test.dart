import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redkeep/features/watchlist/data/tmdb_client.dart';
import 'package:redkeep/features/watchlist/domain/catalog_title.dart';
import 'package:redkeep/features/watchlist/domain/watch_title.dart';

void main() {
  http.Response json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('a v3 key travels as api_key; a v4 token as a bearer header', () async {
    final requests = <http.Request>[];
    final mock = MockClient((request) async {
      requests.add(request);
      return json({'results': []});
    });
    await TmdbClient(mock, apiKey: 'abc123').search('alien');
    await TmdbClient(mock, apiKey: 'eyJhbGciOi.token').search('alien');

    expect(requests[0].url.queryParameters['api_key'], 'abc123');
    expect(requests[0].headers.containsKey('Authorization'), isFalse);
    expect(requests[0].url.path, '/3/search/multi');
    expect(requests[0].url.queryParameters['include_adult'], 'false');
    expect(requests[1].url.queryParameters.containsKey('api_key'), isFalse);
    expect(requests[1].headers['Authorization'], 'Bearer eyJhbGciOi.token');
  });

  test(
    'multi search keeps films and shows, drops people and duplicates',
    () async {
      final client = TmdbClient(
        MockClient(
          (_) async => json({
            'results': [
              {
                'media_type': 'movie',
                'id': 603,
                'title': 'The Matrix',
                'release_date': '1999-03-30',
                'poster_path': '/m.jpg',
                'genre_ids': [28, 878],
                'vote_average': 8.2,
                'vote_count': 26000,
              },
              {'media_type': 'person', 'id': 6384, 'name': 'Keanu Reeves'},
              {
                'media_type': 'tv',
                'id': 1399,
                'name': 'Game of Thrones',
                'first_air_date': '2011-04-17',
                'genre_ids': [10765],
              },
              {'media_type': 'movie', 'id': 603, 'title': 'The Matrix'},
              {'media_type': 'movie', 'id': 9, 'title': '  '},
            ],
          }),
        ),
        apiKey: 'k',
      );
      final results = await client.search('matrix');

      expect(results.map((r) => r.key.value), ['movie:603', 'tv:1399']);
      expect(results.first.year, 1999);
      expect(results.first.genres, ['Action', 'Science Fiction']);
      expect(results.first.posterPath, '/m.jpg');
      expect(results.last.media, WatchMedia.tv);
      expect(results.last.genres, ['Sci-Fi & Fantasy']);
      expect(results.every((r) => !r.detailed), isTrue);
    },
  );

  test(
    'film details read the director, cast, keywords and regional providers',
    () {
      final title = TmdbClient.detailsFromJson(WatchMedia.movie, {
        'id': 603,
        'title': 'The Matrix',
        'tagline': 'Welcome to the Real World.',
        'release_date': '1999-03-30',
        'runtime': 136,
        'genres': [
          {'id': 28, 'name': 'Action'},
        ],
        'keywords': {
          'keywords': [
            {'name': 'simulated reality'},
          ],
        },
        'credits': {
          'cast': [
            {
              'name': 'Keanu Reeves',
              'character': 'Neo',
              'profile_path': '/keanu.jpg',
            },
            {'name': 'Carrie-Anne Moss', 'character': ''},
          ],
          'crew': [
            {'job': 'Producer', 'name': 'Joel Silver'},
            {'job': 'Director', 'name': 'Lana Wachowski'},
            {'job': 'Screenplay', 'name': 'Lana Wachowski'},
            {'job': 'Best Boy', 'name': 'Left Out'},
          ],
        },
        'budget': 63000000,
        'revenue': 0,
        'status': 'Released',
        'original_title': 'The Matrix',
        'homepage': 'http://insecure.example',
        'production_companies': [
          {'name': 'Village Roadshow'},
        ],
        'spoken_languages': [
          {'english_name': 'English'},
        ],
        'images': {
          'backdrops': [
            {'file_path': '/b1.jpg'},
          ],
          'posters': [
            {'file_path': '/p1.jpg'},
            {'file_path': 'not-a-path'},
          ],
        },
        'videos': {
          'results': [
            {'site': 'YouTube', 'key': 'clip1', 'name': 'Clip', 'type': 'Clip'},
            {'site': 'Vimeo', 'key': 'v', 'name': 'Elsewhere'},
            {
              'site': 'YouTube',
              'key': 'trail1',
              'name': 'Official Trailer',
              'type': 'Trailer',
            },
          ],
        },
        'recommendations': {
          'results': [
            {
              'id': 604,
              'title': 'The Matrix Reloaded',
              'poster_path': '/r.jpg',
            },
            {'id': 605, 'title': 'No Poster'},
          ],
        },
        'release_dates': {
          'results': [
            {
              'iso_3166_1': 'US',
              'release_dates': [
                {'certification': 'R'},
              ],
            },
            {
              'iso_3166_1': 'GB',
              'release_dates': [
                {'certification': ''},
                {'certification': '15'},
              ],
            },
          ],
        },
        'watch/providers': {
          'results': {
            'US': {
              'flatrate': [
                {'provider_name': 'Max'},
              ],
            },
            'GB': {
              'flatrate': [
                {'provider_name': 'Netflix'},
              ],
              'rent': [
                {'provider_name': 'Apple TV'},
              ],
            },
          },
        },
      }, region: 'GB');

      expect(title.detailed, isTrue);
      expect(title.director, 'Lana Wachowski');
      expect(title.cast.map((c) => c.name), [
        'Keanu Reeves',
        'Carrie-Anne Moss',
      ]);
      expect(title.cast.first.role, 'Neo');
      expect(title.cast.first.profilePath, '/keanu.jpg');
      expect(title.cast.last.role, isNull, reason: 'an empty part is none');
      expect(
        {for (final c in title.crew) c.name: c.role},
        {'Joel Silver': 'Producer', 'Lana Wachowski': 'Director, Screenplay'},
        reason: 'jobs merge per person; minor jobs are left out',
      );
      expect(title.keywords, ['simulated reality']);
      expect(title.providers, ['Netflix']);
      expect(title.rent, ['Apple TV']);
      expect(title.certification, '15', reason: 'the region\'s own rating');
      expect(title.budget, 63000000);
      expect(title.revenue, isNull, reason: 'zero is unknown');
      expect(title.status, 'Released');
      expect(title.originalTitle, isNull, reason: 'same as the title');
      expect(title.homepage, isNull, reason: 'only https links open');
      expect(title.releaseDate, DateTime(1999, 3, 30));
      expect(title.companies, ['Village Roadshow']);
      expect(title.spokenLanguages, ['English']);
      expect(title.backdrops, ['/b1.jpg']);
      expect(title.posters, ['/p1.jpg']);
      expect(title.videos.map((v) => v.youtubeKey), ['trail1', 'clip1']);
      expect(
        title.trailer!.url.toString(),
        'https://www.youtube.com/watch?v=trail1',
      );
      expect(title.recommendations.map((r) => r.title), [
        'The Matrix Reloaded',
      ]);

      final cached = CatalogTitle.fromJson(
        jsonDecode(jsonEncode(title.toJson())) as Map<String, dynamic>,
      )!;
      expect(cached.detailed, isTrue);
      expect(cached.cast.first.role, 'Neo');
      expect(cached.trailer!.youtubeKey, 'trail1');
      expect(cached.recommendations.single.key.value, 'movie:604');
      expect(title.runtime, 136);
      expect(title.tagline, 'Welcome to the Real World.');
    },
  );

  test('show details read creators, aggregate cast and real seasons', () {
    final title = TmdbClient.detailsFromJson(WatchMedia.tv, {
      'id': 1399,
      'name': 'Game of Thrones',
      'first_air_date': '2011-04-17',
      'episode_run_time': [60],
      'created_by': [
        {'name': 'David Benioff'},
      ],
      'aggregate_credits': {
        'cast': [
          {
            'name': 'Emilia Clarke',
            'roles': [
              {'character': 'Daenerys Targaryen'},
            ],
          },
        ],
        'crew': [
          {
            'name': 'Ramin Djawadi',
            'jobs': [
              {'job': 'Original Music Composer'},
            ],
          },
        ],
      },
      'networks': [
        {'name': 'HBO'},
      ],
      'number_of_episodes': 73,
      'last_air_date': '2019-05-19',
      'next_episode_to_air': {
        'season_number': 9,
        'episode_number': 1,
        'name': 'Back',
        'air_date': '2027-01-01',
      },
      'content_ratings': {
        'results': [
          {'iso_3166_1': 'US', 'rating': 'TV-MA'},
        ],
      },
      'keywords': {
        'results': [
          {'name': 'dragon'},
        ],
      },
      'seasons': [
        {'season_number': 0, 'name': 'Specials', 'episode_count': 14},
        {
          'season_number': 1,
          'name': 'Season 1',
          'episode_count': 10,
          'air_date': '2011-04-17',
          'poster_path': '/s1.jpg',
          'overview': 'Winter is coming.',
        },
      ],
    });

    expect(title.key.value, 'tv:1399');
    expect(title.director, 'David Benioff');
    expect(title.cast.single.role, 'Daenerys Targaryen');
    expect(title.crew.map((c) => (c.name, c.role)), [
      ('David Benioff', 'Creator'),
      ('Ramin Djawadi', 'Original Music Composer'),
    ]);
    expect(title.networks, ['HBO']);
    expect(title.episodeCount, 73);
    expect(title.certification, 'TV-MA');
    expect(title.lastAirDate, DateTime(2019, 5, 19));
    expect(title.nextEpisode!.code, 's9e1');
    expect(title.seasons.single.posterPath, '/s1.jpg');
    expect(title.seasons.single.overview, 'Winter is coming.');
    expect(title.keywords, ['dragon']);
    expect(title.runtime, 60);
    expect(title.seasons.map((s) => s.number), [1]);
    expect(title.seasons.single.episodeCount, 10);
  });

  test('a season lists its episodes with air dates', () async {
    final client = TmdbClient(
      MockClient((request) async {
        expect(request.url.path, '/3/tv/1399/season/1');
        return json({
          'episodes': [
            {
              'episode_number': 1,
              'name': 'Winter Is Coming',
              'air_date': '2011-04-17',
              'still_path': '/e1.jpg',
            },
            {'episode_number': 2, 'name': 'The Kingsroad', 'air_date': null},
          ],
        });
      }),
      apiKey: 'k',
    );
    final episodes = await client.season(1399, 1);

    expect(episodes.map((e) => e.code), ['s1e1', 's1e2']);
    expect(episodes.first.airedBy(DateTime(2026)), isTrue);
    expect(episodes.last.airedBy(DateTime(2026)), isFalse);
    expect(episodes.first.stillPath, '/e1.jpg');
  });

  test('details cached before the richer fields are fetched again', () {
    final old = CatalogTitle.fromJson({
      'key': 'movie:603',
      'title': 'The Matrix',
      'cast': ['Keanu Reeves'],
      'detailed': true,
    })!;
    expect(old.detailed, isFalse, reason: 'no version: fetch again');
    expect(old.cast.single.name, 'Keanu Reeves', reason: 'still readable');
  });

  test('failures map to plain reasons', () async {
    Future<TmdbFailure> failure(int status) async {
      try {
        await TmdbClient(
          MockClient((_) async => json({}, status)),
          apiKey: 'k',
        ).trending();
      } on TmdbException catch (e) {
        return e.failure;
      }
      fail('expected a failure');
    }

    expect(await failure(401), TmdbFailure.unauthorized);
    expect(await failure(404), TmdbFailure.notFound);
    expect(await failure(429), TmdbFailure.busy);
    expect(await failure(500), TmdbFailure.unavailable);
  });
}
