<!--
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-FileCopyrightText: 2026 Julian Schneider
SPDX-License-Identifier: GPL-3.0-or-later
-->

# The note preview

The preview renders a note with swift-markdown and shows the result in a `WKWebView`
(`Source/PreviewWebView.swift`, `Source/PreviewViewController.swift`). The page template is
`Source/Preview.bundle/index.html` with the bundled `github-markdown.css`.

## Rendering pipeline

1. `MarkdownRenderer.html(from:)` parses the note. A `MarkupRewriter` removes raw HTML blocks and inline
   HTML and drops links and images whose scheme is `javascript:`, `vbscript:`, `data:` or `file:`, so a
   note cannot inject script into the preview.
2. `PreviewCheckBoxes.linkingCheckBoxes(in:of:)` runs when `tappableCheckBoxes` is enabled: it finds every
   `[ ]`/`[x]` list item of the source and wraps the matching rendered `<input type="checkbox">` in a link.
3. The template is filled and loaded from the bundle. The page keeps its Content Security Policy
   `script-src 'none'`; no note content ever runs.

## Task lists

The renderer emits a bare `<input type="checkbox" disabled>` and wraps the text of the list item in a
paragraph. Without help the box and its text land on separate lines and the list marker stays in front.
`index.html` therefore styles `li:has(> .task-toggle)` and `li:has(> input[type="checkbox"])`:

- the marker is removed and the row gets a little vertical room,
- the box is pulled into the marker's place and the following paragraph becomes inline,
- the clickable link around the box is enlarged with padding, which widens the tap target without moving
  the box.

## Ticking a checkbox

Because note content may not run scripts, a checkbox reports a tap through navigation instead of
JavaScript. Each box becomes

```html
<a class="task-toggle" href="notes-checkbox:<line>:<open|checked>" role="checkbox"
   aria-checked="false" aria-label="Bread"><input aria-hidden="true" …></a>
```

`PreviewWebView` cancels that navigation and hands the target to the view controller, which
`PreviewCheckBoxes.toggling(_:at:)` applies:

- the line number and the state come from the link;
- the state is verified against the note before writing, so a stale link (the note changed elsewhere)
  changes nothing;
- only the single state character is replaced, so the marker, indentation and line endings survive
  (`MarkdownDocument` remembers `\r\n`);
- the app's own content world runs `document.body.innerHTML = …` to re-render in place, which keeps the
  scroll position; if that fails, the page is reloaded with the offset restored.

Read-only notes keep the boxes untappable; `PreviewViewController.allowsCheckBoxToggling` is set from the
note by the editor. The disabled input is hidden from accessibility and the link carries `role`,
`aria-checked` and `aria-label`, so VoiceOver announces a checkbox rather than a link.

## Dark mode

The web view and its scroll view are transparent, and the page background is transparent as well, so the
system background shows through while the first page loads. The bundled stylesheet only defines the light
theme, so `index.html` sets the dark colors (`color-scheme: light dark` plus a `prefers-color-scheme`
block) for text, links, headings, quotes, code, tables and rules.

## Limitations

- Ticking a checkbox is not possible when the preview is opened for a note that cannot be written.
- Custom CSS from the server or from a plugin is not applied.
- The preview renders images with the schemes the policy allows (`https:` and `data:`); relative image
  paths depend on the note's folder and are not resolved against the server.
