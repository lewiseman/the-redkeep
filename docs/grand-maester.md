# Grand Maester: contextual device assistance

M11 adds the floating **Grand Maester** control to writing readers and editors.
It uses Brain's committed device assignments and qualified executor. Opening
ordinary writing does not create the helper controller, inspect model files,
load weights, download anything or run inference. Opening the helper checks
readiness; every generation needs an explicit action. **Open Brain** provides
assignment/download/repair setup. Returning never starts a request automatically.

| Context | Available actions |
| --- | --- |
| Saved Note | Summarize its body; **Rewrite in editor** opens the current/recovered editor without generating. |
| Note editor, including a new recovery draft | Rewrite or summarize the selected body passage, or the whole body with a collapsed/no selection. |
| Saved Diary entry | Summarize its body; open the editor to select a shorter passage. |
| Diary editor, including a new recovery draft | Summarize the selected body passage or whole body. |
| Saved/current Flow, including quick capture | Explicit optional short reflection on the whole thought. |
| Empty, missing, deleted, wrong-date or stale editor source | No executable contextual action. Writing and Brain setup remain available. |

Titles provide provenance but are not sent to the model. The helper does not
concatenate separate records, silently trim writing or chunk it into background
requests. Input must be nonblank and at most **2,000 UTF-16 code units**. Longer
Notes/Diary bodies can use a selected passage in their editor; longer Flow
thoughts require shorter text. The UI uses “characters” for this conservative
code-unit bound. Tokenizer limits can still reject shorter text. Brain retains
its CPU/fallback-off, 2,048 context-token, 96 output-token, 16,000 output-code-unit
and 90-second cooperative limits. Small-model output can invent facts/emotions
or end mid-sentence; functional checks do not establish useful response quality.

## Review and persistence boundary

`features/maester/domain/maester_source.dart` captures feature kind, stable ID,
source revision, complete current body, title/editor version and exact body range.
`MaesterSelection` counts every text/selection/composing change, including a
change undone before the next frame. Synchronous guards read the live editor and
selection as well as the rendered snapshot. Text edits use monotonic editor
change counters. A newer save has a different source revision.

`MaesterController` is a per-interaction, auto-disposed Riverpod controller. The
feature-owned `*_maester_button.dart` adapters resolve their own document/editor
boundaries and recheck authoritative source/draft tokens before generation, after
native cleanup and before acceptance. Readiness and assignments are resolved
again on every attempt; the executor verifies files immediately before loading.
A ready file is not proof of hardware readiness. Missing/incompatible/unassigned
models provide setup, and safe storage/load/generation/cleanup failures remain
visible with explicit retry/check/setup actions.

Streaming text is labeled **incomplete**. It cannot be accepted or copied through
the response-copy button. A proposal becomes available only after successful
native cleanup and validation. Completed summaries/reflections can be viewed or
copied; they have no acceptance/edit action. Copy errors keep the visible result.
All results are temporary: closing/rejecting the helper discards its result.
Nothing adds an AI history table, writes into a different feature or seeds writing.

A rewrite shows the generated replacement and captured original passage.
**Accept replacement** calls `NoteEditorController.acceptReplacement`; generation
and rejection never call it. Acceptance flushes recovery, checks the current
source revision and draft token, and rechecks live selection/editor guards after
awaits before replacing exactly the captured range. It retains the title and
surrounding Unicode text. The result enters the normal working/recovery buffer;
**Save note** is a separate explicit revision-checked commit. Accepting twice is
not possible. If recovery storage subsequently fails, the accepted buffer stays
in memory with the existing recovery failure/retry/copy behavior; durability is
not claimed until recovery succeeds.

Acceptance does not lock out a later database change. If another edit or deletion
occurs immediately after the last read or after acceptance, the buffer can remain
as an independent recovery draft, but the repository's atomic commit check blocks
replacing the newer/deleted source. Manual conflict recovery remains explicit.
See [Notes writing](notes-writing.md) for those save/copy/discard guarantees.

## Cancellation, navigation and presentation

Cancel, helper close/reject, source edits/deletes, selection changes, route/ID
switches and inactive/hidden/paused lifecycle invalidate the request generation.
Late chunks and pending native loads cannot publish a new proposal or edit text.
Only the controller owning native execution cancels that executor; a helper that
finds another Brain request busy cannot cancel the other caller. Pending file/
source checks may finish, but their expired token prevents a subsequent load.
Native cleanup completes before retry becomes available. No automatic resume or
continuous inference occurs on foregrounding. A failed native teardown poisons
Brain until restart; hung native calls remain a cooperative-cancellation limit.

The source route owns both its dialog and controller subscription, including when
a parent reader stays mounted beneath an editor. Route changes remove that
interaction; a newly opened helper starts fresh. Disposal suppresses output
without notifying providers during Flutter unmount. Private source text/results
are not logged by the production helper.

The floating control has a semantic tooltip and no hero animation. Its dialog
uses an immediate transition in all rendering modes, safe areas, keyboard insets
and one scrollable column including all actions. Notes/Diary editors preserve
keyboard/selection when opening it. Shared writing scroll viewports reserve space
beneath their last controls so the floating control does not cover them. No new
artwork, decorative motion, dependency, schema or native configuration is needed.

## Verification and evidence limits

Run from `redkeep/`:

```sh
flutter test test/features/maester
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test tool
```

Fast tests inject models/files/assignments and use fresh containers/disposable
SQLite, without accounts, network, real writing or downloaded models. They cover
context/readiness/setup, streaming/failure/cancel/retry, authoritative source and
draft changes, deletes, changed/undone selections, screen switching, background
lifecycle, rejection, selected acceptance and separate manual commit, copy-only
summary/reflection, long Unicode and both themes at 320×480/3× text with safe areas,
180px keyboard and standard/reduced/simpler presentation.

`tool/verify_maester.dart` is an opt-in alternate native entry point. Its writing
uses only in-memory SQLite; model/report files live under app support
`m11-verification/`. Stage the same exact pinned artifact described in
[Brain](brain.md) as `qwen3-06b-int8-722a0a54.litertlm` in that directory before launch:

```sh
flutter build apk --debug --target-platform android-arm64 -t tool/verify_maester.dart
flutter build ios --simulator --debug -t tool/verify_maester.dart
```

Its report records setup/readiness, native rewrite reject/accept/manual save,
view-only operations and cancellation after a delta for cancel/source/selection/
controller-lifecycle changes. The Diary/Flow capability cases use the synthetic
text boundary; feature UI adapters are covered separately. Controller lifecycle
calls are not evidence of an OS background journey. After checking/exporting
`report.json`, remove only staged verification weights/known generated caches and
restore ordinary builds without clearing app data. Do not distribute this entry
point. Native builds, ordinary UI smoke results and evidence limits are recorded
in the M11 phase record and `docs/evidence/m11/verification.json`.

Physical iOS/Metal, minimum-OS/low-end phones, sustained release latency/thermal/
energy/peak-memory, physical accessibility/IME and native OOM/storage-failure
qualification remain separate evidence gaps. The production artwork host remains
an M12 release prerequisite. M11 does not implement companion/API execution,
retrieval, voice, vision or any later phase.
