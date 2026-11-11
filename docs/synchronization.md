<!--
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-License-Identifier: GPL-3.0-or-later
-->

# Synchronization

`Networking/NoteSessionManager.swift` is the only place that talks to the Notes API
(`Networking/Router.swift`). Notes live in Core Data; a note carries `addNeeded`, `updateNeeded` and
`deleteNeeded` flags that describe unpushed local changes.

## A synchronization run

`sync()` joins an already running run instead of starting a second one, then works through four phases:

1. Delete notes marked `deleteNeeded`.
2. Upload notes marked `addNeeded`.
3. Upload notes marked `updateNeeded`.
4. Pull the list of notes.

Every push re-reads its row first, because earlier awaits may have uploaded, deleted or detached it.

The list request sends `If-None-Match` with the stored ETag and `pruneBefore` with the stored
`Last-Modified`, so the server answers `304` when nothing changed and sends only a one-key stub for notes
that did not change. Responses store both validators again. A stub for a note the database does not know
means the validators are ahead of the database: they are dropped and the list is fetched once more.

Local changes always win over the server copy: `Note.merge(remote:)` skips rows with pending changes, and
`EditableFields` snapshots what a request sent so a newer local edit is not overwritten by the answer.

## Writing a note while the user types

Typing produces one update per typing pause (at most every 0.5 s). A slow server would still answer
several of those requests at the same time; every additional concurrent write adds a file lock on the
server, which ends in `423 Locked` and a client-side timeout (#215).

`update(note:updateModified:)` therefore keeps two sets: notes with an upload in flight and notes that
changed while their upload was in flight.

- An update for a note that is already uploading only marks the note as changed again and returns.
- When the running request finishes, the loop reads the note from Core Data, so the newest content is
  sent, and repeats while the note changed again.
- A failure ends the loop; the note keeps `updateNeeded`, so the next synchronization retries it.
- Notes without a running upload are updated immediately, and different notes never wait for each other.

Requests retry `423` up to twice with a two second delay, in addition to the coalescing above.

## Server ability and settings

`Store.fetchCapabilities(for:)` runs before every synchronization. It stores

- `notesVersion` — whether the Notes app is installed on the server,
- `notesApiVersion` — used by `Router` to choose the URL prefix,
- `directEditingSupportsFileId` — whether the collaborative editor can be opened by file id,
- `serverMajorVersion`, `serverMinorVersion`, `serverMicroVersion` — shown as "Server Version".

If the Notes app is missing, the user is told once per launch instead of getting a cryptic 404 later (#100).
The user's notes folder and file extension are read from `/settings` and written back on change; any
extension the server reports is kept, validated by `FileSuffix` (#143).

## User-facing errors

`iOCNotes/Features/ErrorBanner.swift` shows every failure as a banner that

- disappears after eight seconds and has a "Dismiss" button, because a banner that stayed forever covered
  the editor and could not be closed (#172, #26, #4),
- appears at the top, where it covers the least text on a phone,
- suppresses an identical message for twenty seconds, so a flaky connection cannot repeat it constantly
  (#5). `ErrorBannerPolicy` holds that rule and is unit-tested.

Offline mode and an unreachable host skip synchronization without an error. A cancelled run (dismissed
pull-to-refresh, expired background task) surfaces nothing.

## Known limitations

- Deletions of notes shared with other users are not synchronized between clients; the list only reports
  what the account's own notes endpoint returns.
- Conflicts are resolved as "the local edit wins". There is no three-way merge.
- Uploads are not queued across app launches beyond the Core Data flags.
