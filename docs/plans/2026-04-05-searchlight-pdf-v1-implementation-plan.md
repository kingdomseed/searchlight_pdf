## Overview

Build `searchlight_pdf` v1 as parse-plus-map, not plugin graph. Keep the
backend seam small and do not force a PDFium-based default into the core
package.

**Spec**: `docs/plans/2026-04-05-searchlight-pdf-v1-spec.md`

## Context

- **Structure**: small Dart package; public barrel + `lib/src/api`, `lib/src/extractors`, `lib/src/models`, `lib/src/mappers`, `test`, `docs`
- **State management**: none; stateless APIs/classes
- **Reference implementations**: `../searchlight_parsedoc/lib/src/mappers/searchlight_record_mapper.dart`, `../../../searchlight/doc/app-integration.md`, `../../../tome_keeper/lib/search/data/drift_search_service.dart`, `../../../tome_keeper/tool/pdfrx_text_probe_main.dart`
- **Assumptions/Gaps**: no extraction backend is blessed yet; `pdfrx_engine`
  is rejected as the default core path; Tomekeeper topology stays one global
  index plus filters unless budgets fail

## Plan

### Phase 0: Backend Decision Gate

- **Goal**: keep core package work honest before implementing extraction
- [ ] `docs/research/library-evaluation.md` - record the `pdfrx_engine`
      rejection and current candidate set
- [ ] `docs/plans/2026-04-05-searchlight-pdf-v1-spec.md` - keep the public
      contract backend-agnostic
- [ ] Decide whether the first extractor lives in:
      - `searchlight_pdf` itself, if a pure Dart-compatible backend is found
      - an app- or Flutter-specific adapter, if the best practical backend is
        not a good fit for the core package
- [ ] Verify: `dart analyze && dart test`

### Phase 1: Thin Vertical Slice

- **Goal**: prove bytes -> pages -> page records -> Searchlight query
- [ ] `lib/searchlight_pdf.dart` - export only v1 surface
- [ ] `lib/src/api/pdf_parse_options.dart` - minimal options; no topology knobs
- [ ] `lib/src/api/parse_pdf_bytes.dart` - baseline cross-platform entrypoint
- [ ] `lib/src/extractors/pdf_extractor.dart` - small backend seam
- [ ] `lib/src/extractors/<chosen_backend>_pdf_extractor.dart` - bytes open,
      metadata read, ordered page extraction
- [ ] `lib/src/models/parsed_pdf_document.dart` - document invariants; nullable `title`; nullable `sourcePath`
- [ ] `lib/src/models/parsed_pdf_page.dart` - 1-based `pageNumber`; page text; optional `pageLabel`/`metadata`
- [ ] `lib/src/mappers/searchlight_pdf_page_record_mapper.dart` - deterministic page mapper; caller-owned `documentId`
- [ ] `test/fixtures/basic_text.pdf` - small public text fixture
- [ ] `test/parse_pdf_bytes_test.dart` - extraction happy path
- [ ] `test/searchlight_pdf_page_record_mapper_test.dart` - mapper happy path
- [ ] `test/searchlight_pdf_search_integration_test.dart` - real Searchlight insert/search proof
- [ ] TDD: parse bytes returns ordered pages, `pageCount == pages.length`, 1-based numbering, empty-text pages preserved
- [ ] TDD: page mapper emits `id`, `documentId`, `page`, `title`, `content`; title fallback `document.title ?? document.sourceName ?? documentId`
- [ ] TDD: mapped page records are searchable by `content` and optional `title` in real Searchlight
- [ ] Verify: `dart analyze && dart test`

### Phase 2: Failure Surface And VM Helper

- **Goal**: lock public failure contract; add file convenience path
- [ ] `lib/src/api/parse_pdf_file.dart` - VM-only helper over bytes path
- [ ] `lib/src/errors/pdf_parse_exception.dart` - package error base + typed variants
- [ ] `lib/searchlight_pdf.dart` - export file API + errors; keep surface narrow
- [ ] `test/parse_pdf_file_test.dart` - file path behavior
- [ ] `test/pdf_parse_exception_test.dart` - typed error coverage
- [ ] `README.md` - document VM-only `parsePdfFile(...)`, bytes-first recommendation, no OCR, no viewer widgets
- [ ] `docs/research/library-evaluation.md` - capture actual backend spike
      findings and selection rationale
- [ ] TDD: missing file -> clear file-path error
- [ ] TDD: malformed bytes -> deterministic malformed-PDF error
- [ ] TDD: backend/init failure -> backend extraction error, not fake Searchlight failure
- [ ] TDD: failures produce no partial mapped-record side effects
- [ ] Verify: `dart analyze && dart test`

### Phase 3: Persistence Gate And Measurement Harness

- **Goal**: prove Searchlight persistence story for PDF page records
- [ ] `test/searchlight_pdf_persistence_test.dart` - snapshot round-trip + rebuild expectations at integration layer
- [ ] `tool/measure_pdf_index.dart` - restore time, snapshot size, rebuild time, peak memory probe
- [ ] `docs/research/rollout-validation.md` - budgets, invalidation triggers, rollback gates
- [ ] TDD: page-record snapshot restores with search parity
- [ ] TDD: missing/corrupt/version-incompatible snapshot falls back to rebuild path in harness logic
- [ ] TDD: source-changed signal invalidates snapshot and rebuilds corpus
- [ ] Verify: `dart analyze && dart test`

### Phase 4: Tomekeeper Parity And Ship Readiness

- **Goal**: validate replacement path without forcing cutover
- [ ] `example/searchlight_pdf_page_search_example.dart` - minimal parse/map/search example
- [ ] `docs/research/rollout-validation.md` - add Tomekeeper parity scenarios, manual checklist, rollback triggers
- [ ] `CHANGELOG.md` - record first implemented v1 slice
- [ ] TDD: parity-sensitive fixture queries match Tomekeeper SQLite FTS page attribution expectations
- [ ] TDD: 20-book and 50-book budget runs stay within agreed restore/snapshot/rebuild/memory thresholds, or topology decision reopens
- [ ] Verify: `dart analyze && dart test`

## Risks / Out of scope

- **Risks**: backend selection may remain unresolved longer than the record
  model and mapper work; page-only indexing may feel coarse on dense books;
  corrupted-PDF behavior may vary by backend
- **Out of scope**: OCR, viewer widgets, geometry contract, chunk mapper, convenience populate helper, per-group cache manager, replacing Tomekeeper SQLite FTS before parity gates pass
