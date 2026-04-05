# Searchlight PDF Implementation Plan

## Goal

Bootstrap `searchlight_pdf` as the package that extracts PDF content into
Searchlight-ready records and proves the indexing/search path first.

## Working Decision

Proceed with a page-first implementation and treat `pdfrx_engine` as the
leading extraction backend to validate first.

Keep the package extraction-first:

- no viewer widgets
- no OCR
- no geometry guarantee in the initial public contract
- explicit room for a future alternate extractor backend if needed

## Phase 1: Extraction Spike And Library Lock

1. Add a small extractor abstraction inside the package.
2. Implement the first backend with `pdfrx_engine`.
3. Prove:
   - file loading
   - byte loading
   - per-page text extraction
   - page count and page attribution
4. Record any platform/bootstrap caveats discovered during the spike.

Do not broaden the public API until this spike is proven on real PDFs.

## Phase 2: Fixture-Driven Extraction Tests

1. Add a small public PDF fixture.
2. Add at least one more fixture that resembles the real Tomekeeper target:
   dense multi-page rulebook text.
3. Write failing tests for page extraction.
4. Verify extracted page count and page text attribution.
5. Add failure cases for malformed, encrypted, or unsupported PDFs as the
   chosen backend permits.

## Phase 3: Public Extraction Model

1. Define a narrow public extraction model:
   - parsed document metadata
   - ordered extracted pages
   - optional future metadata bag for geometry
2. Keep the model page-oriented, not viewer-oriented.
3. Preserve:
   - document ID
   - page number
   - title/source metadata
   - source path when available

## Phase 4: Record Mapping

1. Map extracted pages into Searchlight-ready records.
2. Ship a default page-level mapper first.
3. Keep chunking out of the default mapper initially.
4. Verify the mapped records can be indexed by `searchlight`.

## Phase 5: Search Integration

1. Add an example that creates a `Searchlight` database from PDF-derived
   records.
2. Prove search against page `content` and optional `title`.
3. Document how apps can pair the results with `searchlight_highlight`.
4. Document the hit-to-viewer contract clearly for apps like Tomekeeper.

## Phase 6: Page Chunking

After page-level indexing is proven:

1. Add optional page chunking helpers.
2. Ensure every chunk keeps:
   - `documentId`
   - `page`
   - chunk-local text
   - enough metadata to route back to the owning page
3. Keep page records and chunk records as complementary options, not mutually
   exclusive replacements.

This is likely the right second step for Tomekeeper if page-only search feels
too coarse on very large books.

## Phase 7: Future Extension Notes

Document, but do not implement by default:

- page geometry preservation
- in-view highlight support
- remote-download workflows
- viewer integration
- OCR

## Initial Repo Bootstrap Outcome

This repo currently only preserves the package scope, current understanding,
and implementation plan. Real implementation should begin only after the
extraction spike is written down and accepted.
