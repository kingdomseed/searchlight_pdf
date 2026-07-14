# Library Evaluation

This document captures the concrete library decision surface for
`searchlight_pdf`.

## What "Searchable PDF" Actually Means Here

For Searchlight, the job is not "search a PDF file directly." The job is:

1. load PDF bytes or a local file
2. extract text plus page attribution
3. map the extracted output into Searchlight-ready records
4. preserve enough metadata to route a hit back to the viewer

That is also how larger document-search systems commonly work. They extract
text and metadata first, then index the extracted content rather than indexing
the binary PDF container itself.

## Evaluation Questions

The chosen library or library stack must answer:

- Can it extract text reliably from real PDFs with embedded text?
- Which platforms does it support?
- Can it operate on bytes as well as local files?
- Can it support user-imported and remotely downloaded PDFs?
- Does it expose page-level structure?
- Does it expose text geometry that could support future in-view highlights?
- Is it pure Dart, Flutter-only, or platform-specific?
- What is the dependency and licensing profile?

## V1 Acceptance Threshold

To unblock a first implementation, the chosen stack must support at minimum:

- loading PDF bytes or files
- extracting page-level text
- preserving page numbers
- stable enough behavior for fixture-driven tests

Geometry support is desirable, but not required for the first searchable
version.

## Existing App Baseline: Tomekeeper

Tomekeeper already ships the minimum viable approach:

- it opens PDFs with `pdfrx`
- it extracts text per page
- it stores one searchable row per page in SQLite FTS5
- it returns snippets and page-number attribution

That proves a page-first indexing model is already useful for the first target
app, especially for rulebook-style PDFs where users mainly want "take me to the
right page quickly."

## Candidate Matrix

| Candidate | Fit For `searchlight_pdf` | Strengths | Main Risks / Reasons Not To Lead With It |
| --- | --- | --- | --- |
| `pdfrx_engine` with optional `pdfrx` alignment | Rejected as the default v1 core backend | Aligns with Tomekeeper's current viewer stack and has a clean Dart-facing API | Built on PDFium, required runtime/bootstrap work in practice, and does not match the "pure Dart core, no PDFium default" requirement |
| `syncfusion_flutter_pdf` | Strong fallback / optional backend | Mature text extraction APIs, text finding APIs, can read/edit PDFs, good if a Flutter-only app needs richer extraction helpers | Flutter-only package boundary, licensing is not plain OSS-for-all, less aligned with a general Searchlight companion that should stay broadly reusable |
| `pdfx` | Poor fit for v1 extraction | Viewer/renderer package with broad platform coverage | The public package story is renderer/viewer-first, not text-extraction-first |
| `pdf_text` | Weak fit | Simple page/document text APIs | iOS/Android only and effectively stale |
| `pdf_text_extraction` | Weak fit | Can be useful for desktop/CLI probing | Desktop-wrapper story, native dependency on Xpdf tooling, not a clean cross-platform package base |
| `pdf` | Not a candidate | Good creation library | It is for generating PDFs, not reading and extracting existing PDFs |

## Detailed Notes By Candidate

### 1. `pdfrx_engine` / `pdfrx`

Why it was attractive:

- It aligns with the current Tomekeeper stack instead of introducing a second
  PDF engine.
- The repository separates `pdfrx_engine` as a pure Dart package and `pdfrx`
  as the Flutter plugin/widget layer.
- That split matches the Searchlight family well:
  - `searchlight_pdf` can depend on the extraction engine
  - apps can separately choose whether they also use `pdfrx` for viewing

What makes it especially attractive for Searchlight:

- A page-first API maps naturally to Searchlight record generation.
- The package family already includes text selection and search-oriented types,
  which keeps future geometry-aware highlighting plausible without promising it
  in v1.
- Tomekeeper already has working code that calls page text extraction on
  user-imported PDFs, which lowers execution risk for the first adopter.

Why it is no longer the lead:

- The engine is built on PDFium.
- The probe work surfaced runtime/bootstrap complexity that is not acceptable
  for the default `searchlight_pdf` core path.
- That makes it a mismatch for the current package constraint set:
  - pure Dart core package
  - no PDFium default
  - predictable out-of-box behavior for supported targets

### 2. `syncfusion_flutter_pdf`

Why it is credible:

- It exposes explicit extraction APIs rather than only rendering APIs.
- It appears capable of both extracting text and finding text with richer match
  information than a minimal page dump.

Why it should not lead v1:

- It is a Flutter package boundary, not the cleanest fit for a general
  Searchlight companion package that would ideally remain usable from pure Dart
  contexts.
- Licensing is acceptable for some teams but not neutral in the way an MIT or
  Apache-style dependency is. That raises adoption friction for a general
  ecosystem package.

When to revisit it:

- if we decide the first shipped implementation can live behind a Flutter-only
  adapter boundary instead of the pure Dart core package
- if a Flutter-only consumer needs richer text-find helpers quickly
- if geometry support becomes the main requirement and Syncfusion proves more
  reliable in practice

### 3. `pdfx`

Why it is not the lead choice:

- Its public package positioning is about rendering and viewer widgets.
- The visible API/documentation story emphasizes page rendering to images and
  viewing, not extraction into searchable text records.

That makes it a poor foundation for `searchlight_pdf`, even if it remains a
reasonable viewer choice in some apps.

### 4. `pdf_text`

Why it falls short:

- Platform support is iOS/Android only.
- The package is old enough that it should be treated as a narrow legacy option
  rather than the basis for a new ecosystem package.

### 5. `pdf_text_extraction`

Why it falls short:

- It is better understood as a wrapper around external tooling than as a clean,
  general-purpose Dart/Flutter PDF extraction foundation.
- It may still be useful for one-off desktop validation or CLI research, but
  not as the default backbone of `searchlight_pdf`.

### 6. `pdf`

Why it is out:

- This is a PDF creation library.
- It does not solve the core need here, which is reading existing PDFs and
  extracting searchable text.

## Recommendation

### Recommended v1 backend

Do not lock a default extraction backend into `searchlight_pdf` yet.

Instead:

- keep the public package work focused on typed models, mapping, and backend
  seams
- treat `pdfrx_engine` as a researched rejection for the default core path
- keep `syncfusion_flutter_pdf` as a Flutter-only fallback candidate if we
  decide to ship a consumer-specific adapter later
- continue researching a backend that satisfies pure Dart core expectations

### Recommended package strategy

- Keep `searchlight_pdf` extraction-first.
- Do not make viewer widgets part of the package boundary.
- Introduce a small internal extractor interface so a future alternative backend
  can be added without rewriting the public mapping model.

### Recommended v1 record strategy

Start with one Searchlight-ready record per page.

Why page-first is the right first move:

- it matches Tomekeeper's proven workflow
- page number is the most important attribution key for rulebooks
- it keeps result-to-viewer navigation straightforward
- it is easy to add chunking later without breaking the page-level model

## What To Defer

The following should stay explicitly out of v1 unless the chosen library is
already proving them with little extra complexity:

- OCR
- image-only PDF fallback
- viewer widgets
- guaranteed geometry APIs in the public contract
- section-aware parsing beyond basic metadata
- complex semantic chunking

## Resulting Engineering Direction

The current best engineering direction is:

1. build `searchlight_pdf` around extraction plus record mapping
2. keep extraction behind a narrow backend seam until a backend passes the
   current constraint gate
3. preserve extension points for:
   - page chunks
   - geometry metadata
   - alternate extractors
4. validate on real RPG rulebook PDFs before promising more than page-text
   search
