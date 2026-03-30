# Current Understanding

This document consolidates the current PDF-related understanding that already
exists across the main `searchlight` repo.

## What Is Already Decided

- PDF parsing does not belong in the core `searchlight` package.
- PDF work should live in a separate companion package.
- The first version should focus on extraction plus search integration, not
  rendering.
- The package should preserve enough metadata to map a hit back to a PDF page.
- Exact text-geometry support is desirable but should remain optional until the
  extraction library proves it reliably.

## Core Package Boundary

The root repo currently states that core `searchlight`:

- does not include PDF parsing or rendering
- indexes structured records, not raw files
- can search PDF-derived content only after an extraction layer turns it into
  records

The app-integration guidance already proposes a practical page-level record
shape:

```dart
{
  'id': 'rules-p12',
  'documentId': 'rules',
  'page': 12,
  'title': 'Rules Reference',
  'content': 'Extracted text from page 12...',
}
```

That same guide also calls out the likely workflow:

1. extract text and page metadata from the PDF
2. insert page records into Searchlight
3. search against `title` and `content`
4. map the selected hit back to the PDF viewer

## Package Positioning

The design notes consistently place `searchlight_pdf` as:

- a separate companion package
- above `searchlight`
- separate from `searchlight_parsedoc`
- something that can pair with `searchlight_highlight`

## Interoperability Direction

Current package-family direction:

- `searchlight` handles indexing/querying/persistence
- `searchlight_pdf` should handle extraction and record mapping
- `searchlight_highlight` should remain the post-search highlighting helper
- `searchlight_parsedoc` should remain focused on HTML and Markdown

This means PDF records produced by `searchlight_pdf` should be shaped in a way
that works cleanly with:

- core Searchlight indexing
- optional highlight/snippet generation after search
- future app-level viewer mapping

## Current Non-Goals

The current docs repeatedly treat the following as outside the first phase:

- OCR
- viewer widgets
- viewport integration guarantees
- making PDF support a core-package concern
- forcing parsedoc to become a PDF abstraction layer

## Upstream / Parity Position

Current root-repo research says there is no clear open-source upstream PDF
package target to copy one-to-one in the same way as the current HTML/Markdown
and highlight companions.

That means this package should be treated as a Searchlight-specific companion
package design, even if it reuses ideas from the broader package family.

## Root Source Map

The current understanding above comes from:

- root `README.md`
- root `doc/app-integration.md`
- `docs/research/orama-plugin-package-map.md`
- `docs/research/searchlight-parsedoc-package-spec.md`
- `docs/research/design-decisions.md`
- `docs/plans/2026-03-30-searchlight-post-merge-roadmap.md`
- `docs/superpowers/specs/2026-03-24-searchlight-design.md`

