# Notes: writing, organization and recovery

M06 introduced `/notes`, `/notes/:id` and `/notes/:id/edit`; M07 adds keyword
search, tags, pins, Trash, restore, deliberate permanent deletion and an optional
Markdown preview of committed writing. Editing and recovery remain plain text.
No production writing is seeded. Notes uses the existing Riverpod, go_router,
background Drift database, paper surfaces and rendering policy.

## Ownership and persistence

`features/notes/domain` owns `PlainTextDocument`, `NoteDocument`, `RecoveryDraft`,
metadata-only `NoteListing`, `NotesQuery`, `NotesRepository` and the injected
`NoteLinkLauncher`. Views use the document/editor boundary rather than Drift
rows. Clock and 128-bit lowercase hex IDs are injected. Unicode is stored
exactly, without normalization or Markdown transformation. There is no stored
body limit. Revisions decide freshness; timestamps determine list order.

The same background `redkeep.sqlite` is now schema **4**. It adds a false-by-default
`notes.pinned` column and `note_tags` with a `(note_id, tag)` primary key. Versions
1–3 migrate without changing appearance, onboarding, source text, timestamps,
tombstones, revisions or recovery draft tokens. Historical snapshots are retained.
No importer, embedding/index queue, model, network or sync is needed for writing.

Sources start at revision 1. Text commits, organization, trash and restore each
advance the revision. Organization replaces tags and pin state atomically under
the captured revision; text edits preserve them. Tags are trimmed, internal
whitespace collapsed, lowercased, deduplicated and sorted. The repository accepts
up to 24 tags, each at most 40 UTF-16 code units; commas separate tags in the UI.
Invalid input or failed/stale writes leave the old source and drafts intact.
The reader asks users to save or discard recovery writing before organizing it;
concurrent organization still makes an older draft stale and recoverable as a copy.

## Search and lists

**Search and filters** expands without animation. Space-separated keyword tokens
are literal substrings in committed title/body. Every token must match either
field; tag, pinned-only and Saved/Trash filters also combine with AND. `%`, `_`
and SQL punctuation are ordinary text, passed through query parameters. SQLite
folds ASCII case; other scripts match exactly. This is local substring search,
without stemming, Unicode case folding or semantic retrieval. The search input
allows 256 code units. An exact normalized tag can be selected, and filters can
be cleared while keeping the current Saved/Trash collection.

Saved lists/search and tag choices exclude trashed sources. Trash has its own
matching tag choices. Pinned notes come first, then newest updated timestamp,
then stable ID. Queries return metadata without bodies; list tiles build lazily.
Document streams observe revision/draft tokens and tags before reading one
transactional document snapshot, avoiding a body copy per tag. Recovery drafts
remain a separate, explicitly unfiltered list. Filters live in the provider scope
and survive a reader visit; they are not persisted across app restarts.

Loading uses textual status; empty collections, no matches and failures have
specific messages. Lists/tags/readers provide retries, and failed actions offer
**Reload note**. Failures never expose raw exceptions or file paths.

## Commit and recovery

**Create note** persists an empty recovery draft before opening its ID editor.
Every edit updates the buffer and queues serialized, coalesced recovery writes,
without a debounce window. Drafts hold exact text, captured base revision (0 for
a new source), time and an AUTOINCREMENT compare-and-swap token. They can exist
without a source. A replaced/discarded token is never reused.

A recovered draft opens before committed text. Feedback distinguishes recovery
in progress, durable recovery, failed recovery and an explicitly committed save.
**Save note** flushes the latest buffer, checks the source revision and draft
token, commits the source and removes precisely that draft in one transaction.
**Saved revision N on this device** appears only after success. Overlapping
commits and edits during commit are disabled. **Read committed note** identifies
any separate unfinished draft.

Failed/stale writes and failed cleanup roll back. **Save a copy** gives changed
or deleted-source writing a new ID without silently clearing its original draft.
A failed copy with an installed draft also remains recoverable. **Discard draft**
requires confirmation and checks its token, preserving committed writing.

Back waits for pending recovery; failed recovery keeps the editor open with
retry/copy actions. A failed in-memory buffer is retained in the provider scope
when a platform destination bypasses ordinary back. IDs have separate buffers.
If storage cannot write, text newer than the last durable draft is only in
memory: process termination can lose it. Native disk-full, power-loss/fsync and
OS process restoration are not guaranteed. Notes lists durable drafts on reopen.

## Trash, restore and permanent deletion

**Delete note** confirms moving the source into Trash. Full text, creation time,
tags, pin and any recovery draft remain. Normal readers show **Note unavailable**
without saved content; normal editors reject trashed sources unless recovery
writing exists. Trashed readers offer **Restore note**, **Delete forever** and
an independently retained recovery draft. Restore checks the trashed revision,
preserves metadata/text and advances the revision. An older draft remains stale;
users may save a copy or discard it rather than overwrite the restored source.

**Delete forever** requires typing the exact `DELETE` and pressing **Delete
permanently**. The dialog explains that saved text, tags and the current recovery
draft will be removed and cannot be restored. The transaction requires the
captured trashed revision AND the reviewed draft token (including absence).
A new/replaced draft or a restored/changed source blocks deletion. Any failure
rolls everything back. Success removes those rows, invalidates the local editor
buffer, returns to Notes, and leaves old IDs unavailable. There is no automatic
trash expiry or bulk deletion. This is application deletion, not a promise of
forensic erasure of SQLite pages, backups or copies a user explicitly saved.

## Preview and external links

**Markdown preview** renders the committed body with `flutter_markdown_plus`
**1.0.12**, using Flutter widgets. **Show plain text** returns to the exact source.
There is no WebView or executable HTML. Inline HTML is unsupported. Markdown
images are replaced with an alt-text placeholder: no remote request, file read,
user attachment or extra image decoder is allowed through preview.

Synchronous preview work is bounded at 32,000 UTF-16 code units and 1,000 lines.
Longer bodies show an explicit message to read the complete plain text; writing
is never truncated or transformed. This conservative limit is not a physical
low-end performance qualification.

Links open only after a tap. The application validates complete absolute HTTP(S)
URLs with a host, no credentials, whitespace, controls or backslashes. Relative,
file, data, JavaScript, mail and custom schemes are rejected. The injected
platform adapter uses `url_launcher` **6.3.3**, `LaunchMode.externalApplication`;
false results and plugin exceptions produce a safe retry/copy message. No
`canLaunchUrl` discovery or extra native query permissions are needed.

Official package APIs/platform requirements checked before adoption:
[Markdown package and custom builders](https://pub.dev/packages/flutter_markdown_plus/versions/1.0.12),
[url_launcher platform support and launch handling](https://pub.dev/packages/url_launcher/versions/6.3.3).
The launcher supports SDK 24+/iOS 13+, below the app's Android 30/iOS 15 floors;
Flutter 3.47.5/Dart 3.13.4 satisfies its Flutter 3.41/Dart 3.11 requirements.

## Artwork, routes and accessibility

The live **Create note** control uses the individually selected legacy
`notes_add.png` (original generated 192×192 RGBA), key `notes.add`, through the
existing required-asset resolver. It is decorative beside live button text,
40 logical pixels with a fixed 120-pixel decode width. The pinned
`presentation-m07-v1` pack has four PNGs, 479,916 bytes. Only catalog JSON is
bundled. Existing packs keep their three files and acquire this one missing
file through the usual gate/repair flow. See [assets and startup](assets-startup.md)
and the preserved [provenance](../redkeep/tool/assets/PROVENANCE.md).
No raw artwork, new media type, per-note attachment or picker is introduced.

Routes remain exact canonical paths with lowercase 32-hex IDs, no queries,
fragments or extra segments. Startup/onboarding preserve validated destinations.
Missing/permanently deleted IDs use the existing useful fallback. The stack is
home → Notes → reader → editor with framework back handling. Trash is a list
filter and actions on an existing ID reader, without a replacement navigator or
new OS link registration.

Safe areas, wrapping actions, lazy lists, selectable text and scrollable dialogs
support narrow screens, 3× text and keyboard insets. Dialog actions scroll with
the content so large text cannot hide confirmations; dialogs/filters add no
transition animation. Normal and simpler paper/rendering modes retain all actions.

## Verification and limits

Run the [README](../README.md) checks. Focused suites:

```sh
cd redkeep
flutter test test/features/notes test/core/storage test/app/navigation_destination_test.dart
```

Fresh scopes, disposable SQLite, synthetic writing and injected platform failures
cover 120 search/filter combinations; literal SQL/wildcard characters; Unicode;
tag/pin normalization, persistence and preservation through text edits; stale
source/draft checks; trash, restoration, permanent-delete cancellation and typed
confirmation; transaction rollback; migrations from 1/2/3; background reopen;
malformed Markdown/HTML; blocked/failed links and omitted images; long preview
fallbacks; 2,000-record queries/lazy lists; bounded artwork decode; deleted routes;
and both themes/rendering modes at 320×480, 3× text, safe areas and keyboard insets.

Exact native builds and Android emulator smoke evidence are recorded in the M07
phase record and `docs/evidence/m07/verification.json`. Widget/host SQLite checks
are not physical-device evidence. Native iOS writing/external-browser interaction,
physical accessibility/IME, minimum-OS, low-end/release performance and native
storage/power-loss drills remain unverified. M04 production HTTPS hosting and
M03 AI qualification gaps remain unchanged. Next eligible phase: **M08 — Diary**.

## Contextual assistance (M11)

See [Grand Maester](grand-maester.md) for explicit device actions, Brain setup,
streaming/cancellation and captured-source validation. Summaries/reflections
remain view/copy results. Accepted Note rewrites change only the guarded working/
recovery buffer; committing still requires **Save note**. No inference runs during
ordinary writing or automatically on return to a screen.
