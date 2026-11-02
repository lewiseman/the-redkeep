# Diary: civil dates, writing and recovery

M08 adds a local text notebook with a calendar, day reader, focused entry reader,
manual editing, deletion, recovery drafts and keyword search. The home screen is
now the Diary calendar. Diary, Notes and Appearance are usable destinations;
Flow and later features are not registered. No production writing is seeded.

## Dates and routes

`CivilDate` in `features/diary/domain/civil_date.dart` represents a Gregorian **civil date**, with a
canonical `YYYY-MM-DD` key in years 0001–9999. Invalid dates, rollover, timestamps,
non-padded keys and year zero are rejected. Date arithmetic uses UTC only as a
calendar calculator and reads its year/month/day components; it never turns a
stored diary key into a local instant. DST gaps, repeated hours and a timezone's
skipped local day do not change or erase a valid Gregorian key.

Today is captured from the local components of the injected clock when opening
a calendar. **Open today** reads that clock again when tapped, including after
midnight. Selecting a day fixes that date for the reader, editor, drafts and any
saved copy. An edit after travel or a clock change keeps the original date.
Creation/update/deletion instants are UTC audit/order fields, not date keys.
Source and draft revisions determine freshness even if the device clock moves
backward. Entries within a day appear by creation instant, then stable ID; search
orders dates newest first, then creation instant and ID.

Implemented routes:

| Destination | Route |
| --- | --- |
| Home calendar / current calendar | `/` / `/diary` |
| Calendar focused on a selected date's month | `/diary/calendar/:date` |
| Day reader, including an empty day | `/diary/:date` |
| Committed entry / editor | `/diary/:date/entries/:id` / `.../:id/edit` |
| Local search | `/diary/search` |

Dates and lowercase 128-bit hex IDs are validated before bootstrap/onboarding
continuations. These destinations survive both gates. A valid but missing,
deleted or wrong-date ID does not reveal saved text; wrong-date editors also
reject the document. **Return to day** recovers to the requested date. Previous/
next day and month respect date bounds. **Calendar for this month** retains the
selected date in its route. Normal platform back and reduced-motion transitions
remain framework-owned. Search text is not put in URLs or saved across restarts.

## Ownership and storage

The same background `redkeep.sqlite` is schema **5**. Its new tables are:

- `diary_entries`: ID, civil date key, exact title/body, source revision and audit
  instants. A `(date_key, created_at, id)` index serves day queries.
- `diary_drafts`: independent exact text/date, base revision, update instant and
  an AUTOINCREMENT compare-and-swap token. A draft may predate its source or
  survive its deletion. Tokens are never reused after replacement or discard.
- `diary_days`: optional heading and metadata revision, keyed by civil date.
  Entries are separate rows, never children serialized inside this metadata.

Opening an empty day creates no rows. **Name this day** commits at most 160 UTF-16
code units under its captured metadata revision; an empty heading clears only
that heading. Heading conflicts/failures leave stored metadata and all entries
unchanged and show a retry message. Headings have no recovery draft; entry
writing does. Renaming or deleting an entry does not change a heading or another
entry. Migrations from schemas 1–4 preserve appearance, onboarding, Notes text,
audit fields, revisions, pins/tags, tombstones, drafts and draft sequences.
Historical schema snapshots are retained. There is no legacy JSON-day importer.

Feature domain models contain no Drift, Flutter or plugin types. The repository
maps rows and owns transactional writes. Riverpod composes its repository, clock
and ID generator. The editor controller owns the working buffer; pages use that
boundary rather than database strings. Routine tests override external boundaries
and use fresh scopes and disposable databases.

## Save, recover and delete

**Write an entry** installs an empty durable draft before opening its ID editor.
Each edit updates the buffer and queues serialized, coalesced recovery writes,
without a debounce delay. Back waits for pending recovery; a failed recovery
keeps the editor open with retry and copy actions. Platform navigation that
bypasses back retains a failed buffer within the current provider scope.

Feedback distinguishes recovery in progress, durable recovery, failed recovery
and committed writing. **Save entry** flushes the latest buffer, checks its draft
token and base source revision, commits the entry and removes exactly that draft
in one transaction. **Saved revision N on this device** appears after commit.
Overlapping saves and editing during a save are disabled. Failed source writes
or failed draft cleanup roll back together; text is not cleared on failure.

A recovered draft opens before saved text. The calendar lists independent
recovery drafts with their original dates, including drafts for deleted sources.
A reader identifies separate unfinished writing and offers **Recover draft**.
Changed/deleted sources cannot be overwritten by an old editor. **Save a copy**
uses a new ID on the same civil date, leaving the original source/draft alone.
If a copy commit fails after its draft was installed, that copy draft is listed
for recovery. **Discard draft** confirms and checks the reviewed draft token,
retaining any committed entry.

**Delete entry** confirms removal of committed text. The repository checks the
captured source revision, clears title/body, advances the revision and retains
an ID/date/audit tombstone to reject stale saves. Day lists/search exclude it and
old readers hide its text. An independent draft is deliberately retained and may
be recovered as a new entry or discarded. There is no Diary Trash/restore or
automatic expiry. This is application deletion, not forensic erasure of SQLite
pages, backups or explicitly saved copies.

If device storage cannot write, text newer than the last durable draft remains
only in memory. Process termination can lose those bytes. Native disk-full,
power-loss/fsync and OS process restoration are not guaranteed by widget tests.

## Reading, search and presentation

Day lists query metadata without bodies and build cards lazily. Each consumed
card loads a document snapshot and shows up to 12 lines of text; **Read full
entry** opens the complete selectable plain text. Editors and focused readers do
not truncate or transform writing, including Unicode and long content. Search
and recovery listings show bounded titles without fetching bodies for display.

Search matches literal space-separated tokens against committed title/body;
every token must occur in either field. `%`, `_`, SQL punctuation and other
scripts remain literal parameterized text. SQLite supplies ASCII case folding;
there is no full Unicode case folding, stemming or semantic search. The UI input
is bounded to 256 code units. Queries scan local committed text on the database
isolate; there is no embedding model, index download, account or network.
Loading, empty/no-match, unavailable and retry states use safe textual messages.

Notebook presentation uses paper surfaces, a static binding accent and optional
day headings. Simpler effects removes the accent and existing paper shadow.
No new painter, shader, blur, animation, video, page-fold or decorative ticker is
introduced, so no newly expensive visual effect requires profiling in M08. This
is not a claim of physical low-end frame/memory performance. Calendar cells have
full date semantics and activation actions; narrow screens below 400 logical
pixels or text scaled above 20/14 use a lazy date list instead of a compact grid.
Both modes retain identical functionality. Controls wrap; content, dialogs AND
actions scroll with large text, safe areas and a keyboard. Dialogs are static.

## Verification and limits

From `redkeep/`:

```sh
flutter test test/features/diary test/core/storage test/app
TZ=America/New_York flutter test test/features/diary/civil_date_test.dart test/features/diary/diary_repository_test.dart
TZ=Pacific/Apia flutter test test/features/diary/civil_date_test.dart test/features/diary/diary_repository_test.dart
TZ=Pacific/Kiritimati flutter test test/features/diary/civil_date_test.dart test/features/diary/diary_repository_test.dart
TZ=Etc/GMT+12 flutter test test/features/diary/civil_date_test.dart test/features/diary/diary_repository_test.dart
```

Run the root README's formatting, analysis, full-suite, schema-generation and
native-build commands as well. Tests cover empty/multiple-entry days, metadata
independence/conflicts, migrations 1–4, real background close/reopen persistence,
Unicode/large writing, transaction rollback, delayed/failed saves and recovery,
stale source/draft tokens, copies, discard, deleted IDs, wrong-date navigation,
leap/year boundaries, DST/offset extremes, literal keyword combinations and
calendar semantics actions. Calendar/day/reader/editor/search/dialogs are checked
at 320×480, 3× text, safe padding and keyboard insets in light/dark and normal/
simpler modes. These remain host/widget checks, not physical-device evidence.

Exact commands, native synthetic journeys, artifact hashes and gaps are recorded
in the M08 phase record and [verification evidence](evidence/m08/verification.json).
Physical accessibility/IME, minimum-OS and low-end devices, release performance,
native iOS writing and native storage-failure qualification remain unverified.
The production asset host prerequisite from M04 and AI gaps from M03 remain.
M09 — Flow is the next eligible phase; it is not implemented here.
