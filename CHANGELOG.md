<!--
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-License-Identifier: GPL-3.0-or-later
-->

# Changelog

All notable changes to Nextcloud Notes for iOS are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[semantic versioning](https://semver.org/).

## Unreleased

### Added

- Formatting bar above the keyboard in the internal editor: undo and redo, headings, bold, italic,
  underline, strikethrough, highlight, lists, indentation, quotes, code and Mermaid blocks, details,
  math, callouts, tables and links.
- Syntax highlighting for `==highlighted==` text in the internal editor.
- The editor shows formatted text instead of Markdown source: the delimiters of bold, italic,
  underline, strikethrough, highlight and inline code are hidden, as are the `#` of a heading. They
  stay hidden while editing; the note itself stays Markdown on the server.
- Note list grouped by modification date (Today, Previous 7 Days, Previous 30 Days, months of the
  current year, earlier years) instead of a single flat list, when sorting by most recent.
- Option to open the collaborative editor and the note preview with a swipe from the left screen edge.
- Tappable checkboxes in the preview: ticking one updates the note in place.
- Dark color palette for the preview, and a themed background for the collaborative editor while it loads.
- Setting "Use First Line as Title" to keep the file name of a note when its content changes.
- Support for any file extension the server accepts, not only `.md` and `.txt`.
- `docs/` documentation set and this changelog.

### Changed

- "Show Markdown Source" switches the editor between formatted text with hidden delimiters and the raw
  Markdown, from the note's More menu or Settings → Editing.
- The settings screen is grouped into Account, Editing, Synchronization, Server and About, with an
  explanation under each group.
- The notes list defaults to sorting by most recent, with category grouping still available.
- The note list uses a large navigation title instead of the inline one.
- The server version in Settings is taken from the server capabilities, which are refreshed on every
  synchronization, instead of the cached `/status.php` product version.
- Error banners now hide themselves after eight seconds, carry a "Dismiss" button, appear at the top of
  the screen and suppress identical messages for twenty seconds.
- Signing settings moved out of the shared Xcode project: defaults live in `iOCNotes.xcconfig`, personal
  values in the optional, untracked `Local.xcconfig`. See [docs/local-signing.md](docs/local-signing.md).

### Fixed

- The delete action inside an open note deleted nothing and left the editor open.
- Categories could not be expanded or collapsed.
- Backspace at the start of a line after a list item deleted that line.
- Renumbering an ordered list replaced every copy of the item number in the following items.
- Notes with Windows line endings gained blank lines after pressing Return.
- Pressing Return at the end of a list item containing emoji crashed the editor.
- Tapping a checkbox below a line with emoji crashed or toggled the wrong checkbox.
- Saving while typing only happened after a pause instead of at least every half second.
- A note whose first line contains no space got the title "…".
- `#` and `*` inside a fenced code block were styled as a heading or emphasis; an unclosed fence now
  marks the text below it as code.
- Opening a note in place from Files or iCloud Drive deleted the original document.
- "Synchronize on Start" was saved but ignored, and the app synchronized on every activation.
- Overlapping uploads for one note piled up file locks on the server and ended in `423 Locked` and
  "Error updating note". Uploads for a note are now serialized and coalesced.
- Anonymous `404` responses from servers without the Notes app now produce a clear message.
- Opening a note in the internal editor although the collaborative editor was requested is now explained.
- A suffix returned by the server that is not a valid extension no longer silently falls back to `.txt`.
- The account password is stored with `afterFirstUnlock` accessibility, so the app no longer treats a
  restarted device as signed out and reports `401` before the first synchronization.
