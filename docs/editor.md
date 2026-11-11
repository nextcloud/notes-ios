<!--
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-License-Identifier: GPL-3.0-or-later
-->

# The internal editor

The internal editor is a `UITextView` subclass (`Editor/HeaderTextView.swift`) with a custom text
storage that styles Markdown while showing its characters (`Editor/MarkdownTextStorage.swift`), a layout
manager that replaces list markers with glyphs, and a tap handler for checkboxes. `Source/EditorViewController.swift`
hosts it in a modal navigation controller.

## Formatting bar

`iOCNotes/Views/FormattingBar.swift` is a `UIInputView` used as the text view's `inputAccessoryView`. It
scrolls horizontally on narrow screens and groups its entries like the menu bar of Nextcloud Text:

1. Undo and redo, driven by the text view's own undo manager.
2. Headings menu, bold, italic, underline, strikethrough, highlight.
3. Bulleted, ordered and to-do lists, decrease and increase indentation.
4. Blocks menu (quote, code, Mermaid, details, inline and block math, callouts), table, link.

`iOCNotes/Features/MarkdownFormatter.swift` contains every edit as a pure function on `String` plus an
`NSRange` selection, returning an `Edit` with the replaced range, the replacement and the new selection.
That keeps the behavior testable without UIKit and is what `IOCNotesUnitTests/MarkdownFormatterTests.swift`
exercises.

Rules worth knowing:

- Emphasis toggles by the length of the asterisk run: `*` is italic, `**` bold, `***` both. Toggling bold
  on `***text***` leaves `*text*`.
- Line style edits only touch the lines the selection covers, skip blank lines unless they are the only
  line, and keep the indentation and the bullet character (`-`, `*`, `+`).
- Ordered lists renumber the selected lines; the caret keeps its column in the line's text, not in its
  markup.
- Applying a format goes through `UITextView.replace(_:withText:)`, so it joins the undo stack like
  typing, and sets `isApplyingFormatting` to keep the list handling out of the edit.
- The bar highlights the format at the caret, read from the line's Markdown (headings, lists, quotes) and
  from the attributes of the character before the caret (bold, italic, underline, strikethrough,
  highlight). A heading is never reported as bold, a link is not reported as underline, and a ticked
  to-do is not reported as strikethrough.

Highlighted text (`==text==`) is also styled in the editor itself; `Editor/MarkdownTextStorage.swift`
adds a background color and a `.highlight` attribute.

## Editing behavior

- **Return continues lists.** After a bulleted, ordered or to-do line, Return inserts the matching marker
  on the next line; an empty item ends the list. Renumbering rewrites only the marker, so
  `2. buy 2 pears` stays intact.
- **Backspace joins, it does not delete.** At the start of a line after a list item, Backspace removes an
  empty line; if the line has text, UIKit joins the two lines as usual. Line handling splits on `\n`
  only, so notes with `\r\n` line endings keep them.
- **Caret arithmetic uses UTF-16.** Regex and layout-manager ranges are UTF-16 based; using them as
  `Character` offsets crashed below lines with emoji. `CheckBoxTapHandler.isCheckBoxCharacter(in:at:)`
  reads the character through `NSString`.
- **Saving while typing.** The throttler now saves at most every 0.5 s instead of waiting for a pause:
  `timeIntervalSinceNow` of a past date is negative, so the elapsed time is its negation.
- **Code fences are respected.** Whether a line is code depends on the fences around it, so every edit
  scans the whole note for fenced blocks, including a fence that is still open. Text below an unclosed
  fence is code, matching the preview.
- **Checkbox taps.** Tapping a checkbox rewrites the box in the text storage and reports the change like
  typing, so it is saved and can be undone. Read-only notes never rewrite.
- **Titles.** Only a note that is being created takes its title from its first line, and only while the
  "Use First Line as Title" setting is on (default). Characters a file name cannot contain are removed,
  the title is shortened to 50 characters, and a first line that yields nothing keeps the existing name.
- **Deleting.** The delete action in the more menu asks for confirmation, plays the collapse animation,
  then deletes the note through `NoteSessionManager` and dismisses the editor. It previously only played
  the animation.
- **Leaving the editor.** A left-edge swipe pops the editor, dismisses it or reveals the list of a split
  view, depending on how it was presented. The collaborative editor gets the same gesture and a matching
  slide transition.

## What the editor does not do

- No live preview side by side; the preview is a separate screen.
- No syntax support for footnotes, definition lists or YAML front matter.
- No toolbar customization or keyboard shortcuts for hardware keyboards.
