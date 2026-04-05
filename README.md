# Searchlight PDF

Searchlight PDF is the planned companion package for turning PDF content into
Searchlight-ready records.

This repo is bootstrapped docs-first. The current goal is to preserve the
existing package scope, constraints, and implementation understanding before
locking a concrete extraction library and public API.

## Intended Role

`searchlight_pdf` should sit above the core `searchlight` package and focus on:

- PDF text extraction
- page-attributed extraction
- page-to-record mapping in v1
- document/page metadata preservation for search result attribution
- deferred chunking and geometry exploration only after page-first validation

## Package Boundaries

`searchlight` owns:

- indexing
- querying
- persistence
- filtering, facets, grouping, and sorting

`searchlight_pdf` should own:

- loading PDF bytes or files
- extracting text and page metadata
- mapping extracted output into Searchlight-ready records

`searchlight_highlight` remains the optional companion for:

- excerpts
- highlighted match ranges
- HTML `<mark>` output
- post-search snippet rendering helpers in apps

`searchlight_parsedoc` remains a separate companion for:

- Markdown extraction
- HTML extraction
- document structure normalization for those source types

`searchlight_pdf` should be usable alongside `searchlight_highlight`, and it
may share mapping conventions with `searchlight_parsedoc` where that improves
interoperability. It should not collapse PDF concerns into parsedoc.

## Current V1 Direction

The current documented direction is:

- indexing and search first
- `parsePdfBytes(...)` as the baseline API
- `parsePdfFile(...)` as a VM-only convenience helper
- rendering integration later
- no OCR in v1
- no viewer widgets in v1
- no promise of geometry APIs unless the chosen extraction library proves them
- no convenience population helper in v1

Important backend note:

- if the chosen backend requires runtime/bootstrap setup such as PDFium cache
  directory initialization, that requirement must be documented explicitly by
  the package and treated as part of the backend validation gate

## Current Open Questions

- Which pure Dart or Flutter-compatible PDF library extracts text reliably?
- Which platforms can use that library?
- Can it preserve page-level geometry for future in-view highlights?
- What is the right public input surface for user-imported and remotely
  downloaded PDFs?
- Is page-first mapping sufficient on real Tomekeeper-style PDFs before a later
  chunk mapper is needed?

## Repo Layout

- [`docs/research/current-understanding.md`](docs/research/current-understanding.md)
  consolidates the current root-repo PDF notes
- [`docs/research/library-evaluation.md`](docs/research/library-evaluation.md)
  captures the evaluation gate for extraction libraries
- [`docs/research/package-spec.md`](docs/research/package-spec.md) captures the
  current intended package scope
- [`docs/plans/2026-03-30-searchlight-pdf-implementation.md`](docs/plans/2026-03-30-searchlight-pdf-implementation.md)
  sequences the next implementation work

## Status

This package is not implemented yet. The repository currently exists to hold
the spec, research, and planning needed to implement it cleanly.
