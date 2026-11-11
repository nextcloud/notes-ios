<!--
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-License-Identifier: GPL-3.0-or-later
-->

# AI-generated code

Every change in this branch — application code, tests, documentation and the pull request description
itself — was written by an AI coding agent (BuffY, running inside Freebuff/Codebuff) working from
the repository, its issue tracker and its open pull requests. No part of the diff was typed by hand.

## What that means

- The agent read the code it changed, ran the build, the unit tests and the strict lint locally, and
  repaired what failed before pushing. The evidence is in
  [the pull request description](pull-request.md#7-verification).
- The commits carry `Generated with Codebuff` / `Co-Authored-By: Codebuff` trailers, so the origin
  of each commit stays visible in the log.
- The merged commits of the five upstream pull requests are unchanged and keep their human authors.
  Only the conflict resolutions, the issue fixes and the documentation were generated here.

## What it does not mean

- Generated code is not automatically correct. The test suite covers the changed behavior, but it
  cannot judge product decisions, wording in translated strings, or the user interface on a device.
- The agent could not verify the app visually. Animation, layout in the preview, the formatting bar
  on an iPad and the look of the hidden Markdown delimiters should be checked in a simulator or on a
  device before merging.
- Issues whose report contained no reproduction were not "fixed by guesswork": they are triaged in
  [issue-triage.md](issue-triage.md) and remain open.

## Reviewing it

The diff is grouped by theme in the pull request description, so it can be reviewed area by area:
editor, note list, synchronization, preview, collaborative editor, settings and tooling. The pure
functions in `iOCNotes/Features/MarkdownFormatter.swift` and `iOCNotes/Markdown/PreviewCheckBoxes.swift`
carry their behavior in tests (`IOCNotesUnitTests`), which makes a review of the editing rules
possible without running the app.
