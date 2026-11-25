# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.1.0] - 2026-11-25

### Added

- `PdfTextSource`: the interface an app implements over its PDF engine.
- `normalizePdfPageText`: rejoins words pdfium split across lines (U+0002)
  and keeps their parts as extra terms, collapses letter-spaced capitals,
  expands ligatures, straightens apostrophes, and collapses whitespace and
  control characters. `PdfPageText.rawRange` maps normalized ranges back to
  the raw text.
- `readPdfPages` and `PdfPageRecord`: page-at-a-time records with a
  Searchlight schema.

## [0.1.0-dev.1] - 2026-03-30

### Added

- Bootstrapped the docs-first `searchlight_pdf` companion repo.
- Added package scope, current research, implementation planning, and
  interoperability notes with `searchlight`, `searchlight_highlight`, and
  `searchlight_parsedoc`.

