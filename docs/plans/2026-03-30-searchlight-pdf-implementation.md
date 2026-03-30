# Searchlight PDF Implementation Plan

## Goal

Bootstrap `searchlight_pdf` as the package that extracts PDF content into
Searchlight-ready records and proves the indexing/search path first.

## Phase 1: Library Evaluation

1. Identify candidate PDF extraction libraries.
2. Compare platform support, byte-loading support, reliability, and licensing.
3. Decide whether a pure Dart implementation is sufficient for v1.
4. Record the chosen library and rejected alternatives.

## Phase 2: Fixture-Driven Extraction Tests

1. Add a small public PDF fixture.
2. Write failing tests for page extraction.
3. Verify extracted page count and page text attribution.
4. Add failure cases for malformed or unsupported PDFs.

## Phase 3: Record Mapping

1. Define a page-level record model.
2. Map extracted pages into Searchlight-ready records.
3. Preserve document ID, page number, and title/source metadata.
4. Verify the mapped records can be indexed by `searchlight`.

## Phase 4: Search Integration

1. Add an example that creates a `Searchlight` database from PDF-derived
   records.
2. Prove search against page `content` and optional `title`.
3. Document how apps can pair the results with `searchlight_highlight`.

## Phase 5: Future Extension Notes

Document, but do not implement by default:

- page geometry preservation
- in-view highlight support
- remote-download workflows
- viewer integration
- OCR

## Initial Repo Bootstrap Outcome

This repo currently only preserves the package scope, current understanding,
and implementation plan. Real implementation should begin only after the
library evaluation phase is written down and accepted.

