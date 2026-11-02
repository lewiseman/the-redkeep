# Flow: capture, editing and recovery

M09 adds quick plain-text capture at `/flow`, ID-based reading at `/flow/:id`
and editing at `/flow/:id/edit`. No writing is seeded. Flow needs no account,
network or model once the existing required-artwork startup gate is complete.

## Ownership and storage

`features/flow/domain` owns immutable thoughts, drafts, bounded list metadata
and `FlowRepository`. Its Drift adapter extends the same background primary
`redkeep.sqlite` to schema **6**, with `flow_thoughts` and `flow_drafts`. Versions
1–5 retain all settings, onboarding, Notes, tags, Diary, tombstones and draft
sequences. Historical schema snapshots remain unchanged. Flow's clock and
32-character lowercase hex ID source are injected through Riverpod.

Committed thoughts start at revision 1. Text is stored exactly, including leading
whitespace, Unicode and newlines, without a body limit or transformation.
Whitespace-only writing cannot be committed. Newest-first order uses the UTC
creation millisecond, then ID descending for ties. Editing advances the source
revision and update time without moving a thought in capture order. Wall-clock
changes can affect chronological order; revisions decide write freshness.
Lists query only the first 160 SQLite characters and build tiles lazily. Readers
and editors load the complete document by ID, without the preview bound.

## Composer and drafts

Typing starts serialized, coalesced recovery writes immediately, without a
scheduled debounce window. An AUTOINCREMENT draft token protects replacement,
commit and discard; tokens are never reused. One partial unique index permits
only one durable capture draft. Independent edit drafts use their thought IDs
and appear under **Unfinished edits**. The capture draft reopens directly in
**Catch a thought**, including after a database/process restart.

**Capture thought** locks editing and repeated submission, flushes the latest
buffer, checks the exact draft token and captured source revision, commits the
thought and removes that draft in one transaction. Only then does the composer
clear and report **Thought captured on this device**. Intentional successive
captures get distinct IDs, even when their text or timestamps match. A failed
source write or cleanup rolls back both changes, keeps the composer/draft and
shows a safe retry message. Failed initial reads block writing until retried.

ID editing uses the same controller and draft boundary. **Save thought** reports
a saved revision only after commit. Recovery status distinguishes writing in
progress, durable drafts and failed recovery. Back waits for pending editor
recovery; a failed buffer stays in its provider scope if another destination
bypasses back. Pending writes/commits keep the controller alive until settled.
Navigation is never an implicit discard. A scope/process restart restores the
last durable draft. If storage cannot write, newer bytes may exist only in
memory and can be lost on process termination. No native disk-full, power-loss,
fsync or OS process-restoration guarantee is claimed.

Source revisions and draft tokens prevent stale edits from overwriting changed
or deleted thoughts. **Save a copy** commits under a new ID and retains the
original draft. If copy commit fails, its installed draft also stays under
Unfinished edits. **Discard draft** requires confirmation and the current token;
committed text is kept. Concurrent draft replacement can require copying the
local buffer and reopening the newer saved draft rather than retrying a stale
token indefinitely.

## Deletion, routes and shell

**Delete thought** confirms irreversible committed deletion. It clears the body,
advances the revision and retains an ID/audit tombstone to reject stale writes.
Any independent recovery draft stays recoverable as a new-ID copy. Flow has no
Trash/restore or automatic deletion. This is application deletion, without a
forensic-erasure promise. Missing/deleted readers show **Thought unavailable**;
editors reject them unless a recoverable edit draft exists. Failed deletion
keeps the thought and offers reloading/retry.

Canonical Flow IDs and More survive the existing startup/onboarding continuation
boundary. Malformed IDs, extra segments, queries, fragments and excluded future
routes go to the safe fallback. Home → Flow → reader → editor remains a framework
back stack. A shared shell now provides **Diary / Notes / Flow / More**, with only
**Appearance** under More. `/settings` remains supported, with home underneath.
There are no AI/helper, voice/media, semantic-search, P2P, collaboration or cloud
controls, routes or dependencies.

## Presentation and verification

Flow uses existing static paper surfaces and the central motion/effects policy.
No new expensive decoration, renderer, shader, blur, animation or ticker is
introduced. Simpler effects removes the existing paper shadow. Controls wrap,
writing is selectable, and content/dialog actions scroll with safe areas and
large text. Shell labels wrap and expose selection semantics. The destination
bar hides while a keyboard is open to leave writing space; dismissing the
keyboard restores it. There is no custom back gesture or replacement transition.

Run the root [README](../README.md) checks and:

```sh
cd redkeep
flutter test test/features/flow test/core/storage test/app
```

Tests use fresh scopes, synthetic writing, disposable SQLite and injected time,
IDs and failures. They cover 50 rapid edits; 20 intentional repeated captures;
duplicate submission during delayed recovery/commit; failed recovery, source
writes and cleanup; stale/deleted/replaced drafts; copy/discard; exact large
Unicode close/reopen persistence; migrations 1–5; creation/ID ordering; bounded
previews and a lazy 2,001-thought collection. Widget checks cover composer,
reader, editor and confirmations at 320×480, 3× text, safe padding and 180px
keyboard insets in both themes and rendering modes, plus all four shell
controls at 3× text without a keyboard. Existing Android/iOS back tests still
pass. These are host/widget checks, not physical-device accessibility evidence.

See the M09 phase record and [verification evidence](evidence/m09/verification.json)
for native builds and the Android offline restart journey. Physical accessibility/
IME, native iOS Flow writing, minimum-OS/low-end hardware, release performance
and native storage-failure qualification remain unverified. M04's production
asset-host prerequisite and M03's AI gaps remain unchanged. Next eligible phase:
**M10 — Brain**; it is not implemented here.
