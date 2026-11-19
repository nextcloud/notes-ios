<!--
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-License-Identifier: GPL-3.0-or-later
-->

# Open issue triage

Every issue that was open when this branch was prepared, and what happened to it. The counts are the
complete set: 73 issues, each listed exactly once.

- **Fixed (24)** — the defect is gone, with a test where it can be tested without a device.
- **Partially addressed (5)** — the reported behavior improved, but the issue asks for more.
- **Already available (5)** — the requested capability exists in the app today.
- **Needs information (19)** — no reproducible report, no logs, or a server-side cause.
- **Deferred (20)** — a feature or migration that needs a product decision or a larger change.

See [`editor.md`](editor.md), [`preview.md`](preview.md), [`synchronization.md`](synchronization.md) for
the behavior behind the fixed issues, and [`pull-request.md`](pull-request.md) for the change list.

## Fixed

| Issue | Title | Resolution |
| --- | --- | --- |
| #4 | Make dismissing error windows more obvious | Banner has a labelled "Dismiss" button; it also hides itself after 8 s. |
| #5 | Error message despite successful syncing | Identical error messages are suppressed for 20 s, so a flaky connection cannot repeat them. |
| #8 | Rendering and ticking of checkboxes | Preview task lists are styled and tappable; the editor already toggled them on tap. |
| #19 | Export problem: title "new note" | A new note gets its title from its first line; the note list allows renaming. |
| #26 | Can't dismiss error messages | Same as #4: the banner is dismissible and self-hiding. |
| #30 | Can't properly edit notes (jumps to top, text mangled) | List handling no longer rewrites lines: Return only changes the marker, Backspace joins instead of deleting, line splitting keeps `\n`. |
| #36 | New notes no longer use first line as title | The internal editor applies the first line as title for a new note. |
| #51 | Sort by last updated | The list defaults to most recent (PR #202) and the sort menu keeps category grouping as an option. |
| #58 | File name changes after editing | Editing never renames an existing note; the new "Use First Line as Title" setting also covers new notes. |
| #64 | Unable to edit notes with 4.2.0 on iOS 15 — white screen | The web views are transparent over the system background and the preview has a dark palette, removing the white flash. |
| #100 | No clear message when the Notes app is missing | The capability check reports the missing app once per launch. |
| #116 | Unsupported direct editing not communicated | A one-time notice explains why the internal editor opened. |
| #135 | Code block contents styled as headings | Fenced blocks — including an unclosed fence — are excluded from heading and emphasis styling. |
| #143 | User-defined file extension not supported | Any extension is accepted, shown and sent back to the server. |
| #162 | Edited notes renamed to their first line | Same as #58. |
| #167 | Enable box checking in view mode | Ticking is possible in the preview; read-only notes stay untappable. |
| #168 | Incorrect server version reported | Version comes from the capabilities, refreshed on every synchronization. |
| #172 | Error message covers the notes area | Banner is placed at the top, hides after 8 s and suppresses repeats. |
| #212 | Preview: checkbox and text on separate lines, boxes not tappable | Task-list CSS and checkbox links that toggle the source line. |
| #215 | Overlapping PUTs cause `423 Locked` and timeouts | Writes per note are serialized and coalesced. |
| #217 | Categories cannot be opened or closed | `DisclosureGroup` bound to the persisted expansion state. |
| #218 | White screen while opening a note in dark mode | Themed, transparent web views for both editors and the preview. |
| #219 | Cannot delete notes using the delete button | The delete action deletes the note and dismisses the editor. |
| #222 | Delete button unresponsive inside a note | Same root cause and fix as #219. |

## Partially addressed

| Issue | Title | What is done, what remains |
| --- | --- | --- |
| #33 | Inconsistent editor interface when opening notes, also deleted all data for a note | Editor instability and the emoji crashes are fixed; the reconnect button reported in the issue is untouched. |
| #50 | Tools and table management | Inserting a table is part of the new formatting bar; editing rows and columns interactively is not implemented. |
| #65 | Note contents deleted | Local edits win and the write queue removes overlapping writes, which is the suspected cause; there is no reproduction, so this is not proven. |
| #121 | Swipe to dismiss impossible | Swipe-back from the left edge is restored for both editors (PR #193); the swipe-down gesture the report describes is not back. |
| #224 | iOS Notes app not allowing editing of new/existing notes (`NKError error 1`) | The failure alert already offers switching to the internal editor, and the new notice explains an unsupported server. The direct-editing call itself is server-side and not changed. |

## Already available

| Issue | Title | Where it is |
| --- | --- | --- |
| #52 | Favorites management | Swipe actions and the context menu toggle favorites; favorites sort to the top and show a star. |
| #72 | New settings section | The Settings tab covers account, synchronization, server, title and about. |
| #99 | LAN requests failing before approval | `NSLocalNetworkUsageDescription` is present; the iOS prompt still requires a second attempt by design. |
| #126 | "All notes" section | Uncategorized notes have their own group, and the sort menu shows all notes by date. |
| #166 | Select notes folder from remote server | "Notes Path" in Settings, synchronized with the server's `/settings`. |

## Needs information

| Issue | Title | Why it is blocked |
| --- | --- | --- |
| #1 | App uploads outdated notes version | Old report without a server version, log or steps; the upload path changed completely since. |
| #21 | Setup Notes | Umbrella/tracking issue without a concrete defect. |
| #24 | Not syncing/connecting | No server version, log or reproduction. |
| #31 | No automatic synchronization of shared notes | Needs the server's behavior for shared notes and a reproduction. |
| #34 | Page not found in app token flow | Login flow differs per server setup; no log provided. |
| #46 | Tighter integration on apps within Nextcloud ecosystem | Requires product decisions across apps. |
| #53 | App crashes while refreshing | No crash log; the crash reporter output is needed. |
| #54 | Can't log in: `App token login name does not match` | Server-side token configuration; no instance details. |
| #55 | Can't synchronize with Nextcloud 27.1.4 | Marked "needs info"; no server log or capability dump. |
| #66 | Multiple notes folders created, 404 on delete | Needs the server's `/settings` response and a reproduction. |
| #68 | Images | Report contains no steps. |
| #134 | CloudNotes not displaying all images | Relative image paths depend on the note's folder; a sample note is needed. |
| #142 | Authentication fully broken since 4.4.0 | No logs or server configuration that reproduces it. |
| #146 | "Error syncing notes" | No server error text or version. |
| #161 | 404 after successful login | Needs request/response logs; the missing-Notes-app case now reports itself. |
| #165 | Crash when opening a note | No crash log; `idevicesyslog` output in the report does not contain the crash. |
| #177 | Improvements for iOS Notes | Umbrella issue; individual items are tracked separately. |
| #180 | QR code login returns error | Needs the login flow's error and server version. |
| #185 | Notes 33.0.0 on iPad — still not synching with server (see #171) | No server version or log; likely the same cause as #55. |

## Deferred

| Issue | Title | Reason |
| --- | --- | --- |
| #23 | Share by link | Needs the sharing API and a UI for permissions. |
| #56 | Dedicated app password/2FA support | Needs a login flow redesign; the account password is stored in the keychain today. |
| #73 | "Copy to Nextcloud Notes" Action Extension is broken | The extension target is not part of the Xcode project anymore; needs its own investigation. |
| #88 | Account switcher and status | The data layer stores a single account; multi-account is a larger refactor. |
| #93 | Replace image assets with SF Symbols | Partially done by the redesign; needs an asset-by-asset review. |
| #96 | Support server theme | Requires fetching the server theme and mapping it to the app. |
| #120 | RTL support not functioning as expected | Needs a design and a test matrix for RTL layouts. |
| #130 | Collaborative sharing for notes | Requires the server's sharing endpoints and permissions UI. |
| #138 | App Intents | New subsystem with its own tests and Spotlight integration. |
| #140 | Liquid Glass support | Design work across every screen; handled step by step. |
| #145 | Migrate to Swift 6 | Project-wide concurrency migration; must be its own change. |
| #147 | Exportable logging | Needs a privacy review of the logs and an export UI. |
| #149 | Automated UI tests | The repository has a hermetic unit/integration suite; UI tests need a stable fixture app. |
| #163 | Allow bypassing SSL certificate issues | Deliberately restricted to a saved certificate for the configured host; relaxing it needs a security decision. |
| #164 | Open notes in view mode by default | Product decision about the default editor mode. |
| #173 | Folders | Categories are the current model; nested folders change the data model and the API usage. |
| #174 | Notes on the Apple Desktop App Store | A macOS port is a separate target and release. |
| #175 | Multiple logins on the mobile app | Same refactor as #88. |
| #206 | PIN prompt at app start | Security feature that needs keychain-backed storage and a lockout policy. |
| #209 | Add toggle for grid view layout | New list layout and a setting; needs design. |

## Notes on process

- Issues that were already fixed on `main` before this branch (#52, #72, #166 and the like) were verified
  against the current code rather than assumed.
- Every "fixed" entry was exercised by a unit test or by reading the changed call path; entries whose
  behavior needs a device or a live server are marked partially addressed or deferred instead.
- The triage is deliberately conservative: an issue without a reproduction stays open rather than being
  closed with an unverified fix.
