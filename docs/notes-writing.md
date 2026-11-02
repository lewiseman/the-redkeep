# Notes: writing and recovery

M06 adds `/notes`, `/notes/:id` and `/notes/:id/edit`. Home links to Notes and
Appearance, both usable destinations. Notes are plain text; Markdown preview,
search, tags, pinning, note artwork and trash controls belong to M07. Existing
paper surfaces, system fonts and rendering policy apply without a new media
download or dependency. No production writing is seeded.

## Ownership and storage

`features/notes/domain` owns immutable `PlainTextDocument`, `NoteDocument`,
`RecoveryDraft`, metadata-only listings and `NotesRepository`. Presentation uses
the application document editor/controller, never Drift rows or a collaborative
document type. The ID and wall clock are injected through Riverpod. IDs are 128
random bits represented as 32 lowercase hex characters; revisions, rather than
timestamps, decide whether writing is current. Unicode is stored without
normalization or Markdown transformation. There is no application body limit.

The existing background `redkeep.sqlite` is the sole primary database. Schema
**3** adds `notes` and `note_drafts`; upgrades from both 1 and 2 preserve all
appearance settings and the existing onboarding marker. Historical schema
snapshots remain checked in. No importer, fixture insert, AI, network, index or
sync work is part of note access.

A note has a stable ID, title/body, positive source revision, creation/update
times and nullable deletion time. Creation commits revision 1; edits and deletion
increment it. Deletion retains the complete text and timestamps for M07 restore.
It excludes the source from saved lists and ordinary reading. It does not remove
an outstanding recovery draft. There is no restore or permanent-delete UI yet.

A draft has the note ID, exact title/body, captured base revision (0 for a new
note), update time and a compare-and-swap token. SQLite AUTOINCREMENT supplies
tokens that cannot be reused after commit/discard. Replacing a draft checks its
previous token and base revision in a transaction; another editor's recovery
writing cannot silently be overwritten. Lists select metadata without bodies and
render lazily. Document observations include changes to both source and draft.

## Editing, commit and recovery

**Create note** first persists an empty recovery draft, then opens its ID-based
editor. Creation failure stays on the list with retry guidance. Each text change
updates the working buffer immediately and queues a background recovery write.
Changes during a write coalesce to the latest buffer; writes run serially. There
is no debounce window. A recovered draft always opens before committed text.

Recovery feedback distinguishes **Keeping recovery draft…**, a draft kept on
the device, a failed recovery write, and an explicitly committed save. A recovery
draft is not presented as a committed note. **Save note** flushes the latest
buffer, checks the draft token and captured source revision, writes the source,
and removes only that draft in one transaction. **Saved revision N on this
device** appears only after the transaction resolves successfully. The editor
disables edits and overlapping actions during commit. **Read committed note**
shows the authoritative saved text and identifies a separate unfinished draft.

Failed note writes, stale sources and failed cleanup roll back without clearing
the draft. If the source changed or was deleted, the user can explicitly **Save
a copy** under a new ID; both the source and original draft are retained. If a
copy's commit fails after its draft was persisted, that draft is also available
in Recovery drafts. A changed draft token blocks overwriting that other draft;
the current in-memory buffer can still be saved as a copy.

Back navigation waits for an outstanding recovery write. A failed recovery write
keeps the editor open with retry/copy actions. A failed buffer is also retained
within the current provider scope if a new platform destination bypasses normal
back navigation. Ordinary navigation after durable recovery may leave the editor
without a prompt; Notes exposes a recovery entry for reopening. Switching IDs
creates a separate presentation buffer. **Discard draft** requires confirmation,
checks its token and removes only recovery writing, keeping any committed note.
**Delete note** requires a separate confirmation and source revision check.

Recovery persistence is asynchronous. If SQLite cannot write, the latest buffer
is only in memory until retry or a copy succeeds; process termination in that
state can lose changes newer than the last durable draft. The UI reports this
failure and never claims it was saved. No app can guarantee a successful write
to unavailable/full storage. Native power-loss/fsync and OS process-restoration
guarantees are not claimed. Process reopening finds drafts through the Notes
list; a stable editor URI can also reopen one directly.

## Routes and accessibility

The navigation boundary accepts only the exact Notes paths and lowercase hex
IDs, without query/fragment/extra segments. Invalid IDs use the shared safe
fallback; valid missing/deleted IDs show **Note unavailable** and a return to
Notes. A retained draft can be opened there, including after source deletion.
Startup, asset repair and onboarding preserve validated note/editor URIs.
Routes receive IDs, not live documents. The stack is home → Notes → reader →
editor, including direct entry, with framework back behavior when recovery is
durable. No new OS link registration is introduced.

Safe areas, keyboard-resizing scroll views, wrapping actions, selectable reading
text and input labels support narrow screens and large text. Paper uses the
shared normal/simpler-effects policy; no animation, custom font or decorative
asset is introduced for Notes. M07 owns selected note artwork through the
existing resolver.

## Verification

Run the [README](../README.md) checks and focused suites:

```sh
cd redkeep
flutter test test/features/notes test/core/storage test/app/navigation_destination_test.dart
```

Tests use fresh provider scopes, disposable SQLite databases and synthetic text.
They cover schema/data preservation, create/edit/delete, exact committed
feedback, SQL-triggered transaction rollback, failed recovery/commit/retry,
stale source and draft tokens, explicit copies/discard, navigation/back,
ID switching and missing/deleted/invalid routes. Background file reopen checks
preserve large Unicode bodies, new/existing drafts and tombstones. Widget checks
exercise reading/editing a large body and both themes at 320×480, 3× text,
safe-area/keyboard insets, normal and simpler/reduced rendering.

Exact native offline-writing checks, build identifiers and outstanding physical
device/accessibility qualifications are recorded in the M06 migration record.
