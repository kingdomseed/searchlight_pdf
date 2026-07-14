<goal>
Build `searchlight_pdf` as a reusable companion package that converts PDF files
or bytes into Searchlight-ready records without making PDF support a core
Searchlight responsibility.

The package matters because Searchlight already handles indexing, ranking,
filtering, grouping, persistence, and restore for structured records, but it
does not own source-format extraction. Tomekeeper is the first consumer and
already proves that page-attributed PDF text search is valuable for tabletop RPG
libraries with 20 to 50 books. This package should turn that app-specific
extraction path into a clean, reusable Searchlight ecosystem package.

Primary beneficiaries:
- Searchlight package consumers who need PDF ingestion above core
- Tomekeeper, which needs a portable extraction-plus-record-mapping layer
- future apps that want PDF search with Searchlight without adopting a PDF
  viewer package contract
</goal>

<background>
Tech stack and constraints:
- Dart package above `searchlight`
- keep the extraction backend undecided until it satisfies the pure Dart core
  constraints
- `parsePdfBytes(...)` is the cross-platform baseline API
- `parsePdfFile(...)` is a VM-only convenience helper
- default Searchlight algorithm for v1 evaluation should be BM25
- no viewer widgets in v1
- no OCR in v1
- page-first indexing in v1
- no `SearchlightPlugin` lifecycle object for ingestion
- interoperability with `searchlight_highlight` must happen through record
  shapes, not direct dependency
- backend-specific bootstrap caveats must be documented explicitly if the chosen
  PDF engine requires runtime initialization or cache-directory setup

Project context:
- `searchlight` core indexes structured records and owns BM25 / QPS / PT15,
  filtering, grouping, sorting, persistence, and restore
- `searchlight_parsedoc` already proves the companion-package pattern for
  source extraction above core
- Tomekeeper currently uses `pdfrx` plus SQLite FTS5 with one searchable row
  per PDF page

Files to examine:
- `@/Users/jholt/development/jhd-business/searchlight/doc/app-integration.md`
- `@/Users/jholt/development/jhd-business/searchlight/.companions/searchlight_pdf/docs/research/current-understanding.md`
- `@/Users/jholt/development/jhd-business/searchlight/.companions/searchlight_pdf/docs/research/library-evaluation.md`
- `@/Users/jholt/development/jhd-business/searchlight/.companions/searchlight_pdf/docs/research/package-spec.md`
- `@/Users/jholt/development/jhd-business/searchlight/.companions/searchlight_parsedoc/lib/src/api/populate.dart`
- `@/Users/jholt/development/jhd-business/searchlight/.companions/searchlight_parsedoc/lib/src/mappers/searchlight_record_mapper.dart`
- `@/Users/jholt/development/jhd-business/searchlight/lib/src/core/database.dart`
- `@/Users/jholt/development/jhd-business/tome_keeper/lib/search/data/drift_search_service.dart`
- `@/Users/jholt/development/jhd-business/tome_keeper/tool/pdfrx_text_probe_main.dart`

Output path for this work:
- `./.companions/searchlight_pdf/`
</background>

<user_flows>
Primary flow:
1. An app has one or more PDF files or raw PDF bytes it wants to make
   searchable.
2. The app calls `searchlight_pdf` extraction APIs and receives a typed PDF
   model with document metadata and ordered pages.
3. The app maps those pages into Searchlight-ready records using the default
   page mapper and a caller-owned `documentId`.
4. The app inserts those records into a `Searchlight` database, persists a
   snapshot, restores later, and executes in-memory search.
5. When a search result is selected, the app uses `documentId` and `page` to
   open the correct PDF page in its own viewer.

Alternative flows:
- One-book scope: the app indexes one PDF and searches only that book.
- Group scope: the app indexes many PDFs and filters by `groupId` or equivalent
  collection field at search time.
- Whole-library scope: the app restores one global corpus and searches all
  indexed PDFs with optional filters.
- Pre-fetched bytes: the app downloads or otherwise obtains PDF bytes itself
  and calls `parsePdfBytes(...)` without any file-path helper.

Error flows:
- Missing file: extraction fails with a package-specific error that clearly
  identifies the path and failure mode.
- Unsupported or malformed PDF: extraction returns a deterministic failure
  without partially inserting records.
- Encrypted or image-only PDF: the package reports unsupported or empty-text
  behavior clearly and does not pretend OCR exists.
- Backend limitation or runtime initialization failure: the package surfaces a
  clear extraction error and does not hide the backend as if Searchlight itself
  failed.
</user_flows>

<requirements>
**Functional:**
1. Implement `searchlight_pdf` as a companion/helper package above
   `searchlight`, not as a `SearchlightPlugin`.
2. Expose explicit extraction APIs for local files and raw bytes:
   `parsePdfFile(...)` and `parsePdfBytes(...)`.
3. Treat `parsePdfBytes(...)` as the baseline cross-platform API and document
   `parsePdfFile(...)` as VM-only.
4. Return a typed extraction model with one document object and ordered page
   objects rather than raw maps as the primary API.
5. Keep extraction source-oriented. Do not require parsing to invent
   application-stable `documentId` values.
6. Preserve page attribution in every extraction result with ordered,
   **1-based** `pageNumber` values.
7. Define v1 extraction invariants explicitly:
   - pages are ordered by ascending page number
   - `pageCount == pages.length`
   - empty-text pages are still represented
   - `sourcePath` is nullable for byte inputs
   - `title` is nullable
   - `metadata` is non-indexed extension data by default
8. Ship a default page-level Searchlight mapper that requires caller-owned
   `documentId` input and emits deterministic Searchlight-ready records with at
   minimum `id`, `documentId`, `page`, `title`, and `content`.
9. Define the page mapper title fallback order explicitly:
   `document.title ?? document.sourceName ?? documentId`.
10. Keep Searchlight ownership clear: `searchlight_pdf` extracts and maps;
    `searchlight` owns insert, index creation, ranking, filtering, grouping,
    sorting, persistence, and restore.
11. Keep `searchlight_highlight` optional and post-search only. Do not add a
    direct dependency from `searchlight_pdf` to `searchlight_highlight`.
12. Keep `searchlight_parsedoc` separate. Reuse naming and mapper conventions
    where helpful, but do not route PDF extraction through parsedoc models or
    APIs.
13. Isolate backend usage behind a small extractor interface so a later backend
    can be selected without public API churn.
14. Document backend spike findings explicitly, including why PDFium-coupled
    options are not currently acceptable as the default core path.
15. Support the first Tomekeeper topology with one global index plus filters
    rather than baking collection topology decisions into the package API.
16. Use BM25 as the default v1 Searchlight algorithm unless measured evidence
    later proves another algorithm is strictly better for Tomekeeper’s
    requirements.
17. Keep scope filters compatible with the topology decision by relying on
    schema-declared fields such as `documentId` and optional `groupId`.

**Error Handling:**
18. Define package-specific error types for at least:
    missing file, unsupported file state, malformed PDF, and extraction
    backend failure.
19. Ensure file and byte extraction failures do not produce partially mapped
    records or partial Searchlight population side effects.
20. Empty extracted text must be representable without being silently rewritten
    into fake content or OCR-like behavior.

**Edge Cases:**
21. Preserve compatibility with one-book, many-book, and filtered group/library
    corpora by always carrying `documentId` and `page` through mapped records.
22. Keep the default mapper page-first even if future chunk mapping is planned.
23. Frame chunking as a later **mapping** strategy, not a replacement for the
    page-attributed extraction model.
24. Allow document metadata such as `sourcePath`, `sourceName`, `pageLabel`,
    and optional `metadata` bags without forcing those fields into the indexed
    schema.
25. Do not make viewer-specific assumptions about outline trees, page labels,
    geometry, or rendering state in the typed extraction model.
26. Treat geometry as optional future metadata only. Do not promise a stable
    geometry contract in v1.
27. Define snapshot invalidation triggers for app integrations:
    source file modified, source file deleted, source import added, or snapshot
    missing/corrupt/version-incompatible.

**Validation:**
28. Add fixture-driven extraction tests that prove page counts, page ordering,
    **1-based** page numbering, and page text attribution on at least one small
    public fixture and one denser Tomekeeper-style PDF fixture.
29. Add mapper tests that prove deterministic page record output, preserved
    attribution fields, and the documented title fallback order.
30. Add runtime integration tests that prove extracted page records can be
    inserted into a real Searchlight database and queried by `content` and
    optional `title`.
31. Add persistence tests that prove:
    - snapshot round-trip restore
    - missing snapshot fallback
    - corrupt snapshot fallback
    - rebuild-on-source-change behavior at the integration layer
32. Add coexistence/rollout tests or documented manual validation that compare
    Tomekeeper’s current SQLite FTS path against the Searchlight path on the
    same PDFs for parity-sensitive scenarios.
33. Add documentation-level checks or public API tests that prove the exported
    v1 surface remains limited to parse APIs, typed models, and the page mapper.
34. Define measurable topology budgets for representative 20-book and 50-book
    libraries before blessing one global index as the default:
    - restore time
    - snapshot size
    - peak memory
    - rebuild time
</requirements>

<boundaries>
Edge cases:
- Encrypted PDF: fail clearly; do not implement decryption in v1.
- Image-only PDF or scanned PDF: allow zero or near-zero extracted text; do not
  fake OCR.
- PDF metadata missing or poor quality: fall back to app-supplied document IDs
  and source names where possible; do not overfit speculative title logic.
- Very large PDF: extraction may be slower, but record attribution must remain
  correct.

Error scenarios:
- File path does not exist: return a clear file-path error.
- Byte payload is not a valid PDF: return a deterministic malformed-PDF error.
- Backend initialization/runtime failure: return a backend extraction error with
  enough context for app logging.
- Searchlight insert failure after mapping: surface the insert failure as a
  Searchlight concern, not a parser concern.
- Snapshot missing/corrupt/version-incompatible: the integration must rebuild
  rather than presenting stale or unusable search state.

Limits:
- No OCR in v1.
- No viewer widgets in v1.
- No remote-download helper in v1; callers fetch bytes themselves.
- No guaranteed geometry contract in v1.
- No plugin-graph registration or `SearchlightPlugin` object for ingestion.
- No topology-specific cache manager inside `searchlight_pdf`; index topology
  decisions stay in app code.
- No convenience population helper in v1. Revisit only after parse, model, and
  mapper semantics are proven and its write semantics can be specified exactly.
- No rollout that replaces Tomekeeper’s current search path before dual-path
  parity and persistence gates are met.
</boundaries>

<discovery>
Before implementation is locked, answer these questions through code inspection
and a thin backend spike:

1. Which backend can satisfy all of these at once:
   - file extraction
   - byte extraction
   - page count
   - page text
   - optional metadata hooks
   - no PDFium default in the core package
2. What title derivation sources are actually reliable in practice:
   PDF metadata, outline/title data, filename, or app-provided values?
3. Is page-only indexing sufficient on dense RPG fixtures, or do we
   immediately need a deferred chunking mapper design note?
4. Which backend/runtime caveats must be documented for desktop/mobile/web
   consumers before public release?
5. What exact bootstrap requirements must be documented if the backend requires
   cache-directory or runtime initialization before extraction?
6. What are the measured restore-time, snapshot-size, rebuild-time, and memory
   characteristics for representative 20-book and 50-book libraries?
</discovery>

<implementation>
Create or modify these paths:

- `./.companions/searchlight_pdf/lib/searchlight_pdf.dart`
- `./.companions/searchlight_pdf/lib/src/api/parse_pdf_bytes.dart`
- `./.companions/searchlight_pdf/lib/src/api/parse_pdf_file.dart`
- `./.companions/searchlight_pdf/lib/src/api/pdf_parse_options.dart`
- `./.companions/searchlight_pdf/lib/src/extractors/pdf_extractor.dart`
- `./.companions/searchlight_pdf/lib/src/extractors/<chosen_backend>_pdf_extractor.dart`
- `./.companions/searchlight_pdf/lib/src/models/parsed_pdf_document.dart`
- `./.companions/searchlight_pdf/lib/src/models/parsed_pdf_page.dart`
- `./.companions/searchlight_pdf/lib/src/mappers/searchlight_pdf_page_record_mapper.dart`
- `./.companions/searchlight_pdf/lib/src/errors/` (or equivalent package error
  definitions)
- `./.companions/searchlight_pdf/test/fixtures/`
- `./.companions/searchlight_pdf/test/extractors/`
- `./.companions/searchlight_pdf/test/mappers/`
- `./.companions/searchlight_pdf/test/runtime/`
- `./.companions/searchlight_pdf/README.md`
- `./.companions/searchlight_pdf/docs/research/library-evaluation.md`
- `./.companions/searchlight_pdf/docs/research/package-spec.md`
- `./.companions/searchlight_pdf/docs/plans/2026-03-30-searchlight-pdf-implementation.md`

Patterns to use:
- explicit top-level parse functions
- typed extraction model first, generic maps second
- stateless mappers
- one small backend abstraction layer
- page-first default record strategy
- caller-owned document identity at the mapper boundary
- explicit runtime matrix documentation

What to avoid and why:
- Avoid `SearchlightPlugin` ingestion because plugin ordering and sync create
  semantics are the wrong abstraction for async PDF extraction.
- Avoid parsedoc model reuse because DOM-style `tag/path/attributes` structure
  is not the right public model for page-oriented PDFs.
- Avoid viewer-widget integration because it couples ingestion to app UI and
  blocks a clean pure-package release.
- Avoid chunking as the default record strategy because it weakens the clearest
  page-routing contract before real fixtures prove the need.
- Avoid remote-download helpers in v1 because apps can fetch bytes themselves
  and the package should not over-own network concerns.
- Avoid convenience populate helpers in v1 because they blur write semantics
  before the parse/model/mapper contract is stable.
</implementation>

<stages>
Phase 1: Extraction spike and backend lock
- Implement the backend abstraction before locking the first extractor.
- Prove file and byte extraction on real fixtures.
- Verify page counts, page ordering, **1-based** page numbering, and extracted
  page text.
- Record backend/runtime caveats before broadening the public API.

Phase 2: Public typed model and page mapper
- Add `ParsedPdfDocument` and `ParsedPdfPage`.
- Add the default page-level record mapper.
- Verify deterministic IDs, documented title fallback, and preserved
  attribution fields.

Phase 3: Searchlight runtime proof
- Insert mapped page records into a real Searchlight database.
- Prove search by `content` and optional `title`.
- Persist and restore a snapshot successfully.
- Prove missing/corrupt snapshot fallback expectations in the integration path.
- Demonstrate scope-by-filter with `documentId` and optional `groupId`.
- Use BM25 as the default first algorithm for these proofs.

Phase 4: Package ergonomics and docs
- Export the accepted public surface from `lib/searchlight_pdf.dart`.
- Update README and research docs to reflect final backend, limits, runtime
  matrix, page numbering convention, and integration expectations.

Phase 5: Tomekeeper rollout guidance
- Document the coexistence-first rollout:
  use `searchlight_pdf` + Searchlight alongside the existing SQLite FTS path
  before replacement.
- Recommend one global index plus filters as the first topology.
- Define dual-path parity checks on the same imported PDFs.
- Define rollback triggers if Searchlight diverges materially in correctness,
  persistence stability, or user-visible responsiveness.
- Defer chunking, geometry contracts, and search-engine replacement decisions
  until measurements exist.
</stages>

<illustrations>
Desired behavior example:

```dart
final parsed = await parsePdfFile(
  '/books/rules.pdf',
);

final records = const SearchlightPdfPageRecordMapper().map(
  document: parsed,
  documentId: 'rules',
);

final db = Searchlight.create(
  schema: Schema({
    'documentId': const TypedField(SchemaType.enumType),
    'page': const TypedField(SchemaType.number),
    'title': const TypedField(SchemaType.string),
    'content': const TypedField(SchemaType.string),
  }),
);

for (final record in records) {
  db.insert(record);
}
```

Undesired behavior examples:
- a `SearchlightPlugin` that tries to open files during database creation
- a default mapper that emits chunk-only IDs without page attribution
- a parser API that hides whether it accepted bytes, file paths, or URLs
- a public model that exposes viewer-widget state instead of extraction results
- a parse layer that invents unstable document IDs differently for file and
  byte inputs
</illustrations>

<validation>
Require baseline automated coverage outcomes for:
- extraction logic and backend error handling
- mapper output correctness
- Searchlight runtime integration
- persistence and restore behavior
- documented Tomekeeper-facing topology expectations

TDD expectations:
- Follow behavior-first vertical-slice TDD.
- Work one failing test at a time, then minimal implementation, then refactor.
- Start with the highest-confidence public behaviors in this order:
  1. file extraction happy path
  2. byte extraction happy path
  3. malformed/missing input failures
  4. 1-based page numbering and model invariants
  5. page mapper deterministic output
  6. Searchlight integration by `content`
  7. Searchlight integration by `title`
- Keep seams explicit:
  - one extractor interface for backend isolation
  - deterministic document ID injection through options or mapper inputs
  - fixture-based tests rather than hidden environment dependence
- Prefer real fixtures and fakes over heavy mocking.
- Mock only true external boundaries if needed; do not mock the package’s own
  value models or mapper behavior.

Journey/test split:
- Unit tests:
  - parse option behavior
  - extracted model invariants
  - mapper output
  - package-specific errors
- Runtime integration tests:
  - extracted pages inserted into a real Searchlight database
  - search finds expected page records
  - filters by `documentId` and optional `groupId` behave correctly
  - snapshot persist/restore round-trip works
  - missing/corrupt snapshot rebuild path is exercised
- No robot or widget tests are required for v1 because this package is not a
  viewer/UI surface.

Verification details:
- At least one fixture proves non-empty text on multiple pages.
- At least one denser RPG-style fixture proves page attribution on a realistic
  rulebook-like document.
- Additional fixtures or fixture-derived failure cases cover:
  - zero-text but valid PDF
  - malformed or truncated bytes
  - metadata/title fallback behavior
  - Unicode/page-label oddities where practical
- Tests prove `pageNumber` values are 1-based and that `pageCount ==
  pages.length`.
- Tests prove empty-text pages are still represented in the parsed model.
- Integration tests prove a selected hit still contains enough data to route an
  app back to `documentId` + `page`.
- Persistence tests prove round-trip restore and fallback/rebuild behavior.
- Topology validation records measured restore time, snapshot size, peak memory,
  and rebuild time for representative 20-book and 50-book corpora.
- README examples compile against the final public API.
</validation>

<done_when>
1. `searchlight_pdf` exposes explicit file and byte parse APIs with a typed
   public extraction model.
2. The public docs explicitly state that `parsePdfFile(...)` is VM-only and
   `parsePdfBytes(...)` is the baseline cross-platform API.
3. The extraction model and tests lock 1-based page numbering, ordered pages,
   and `pageCount == pages.length`.
4. Backend bootstrap/runtime caveats are documented for each evaluated option.
5. A first backend is selected only after it passes the current package
   constraints, or the package remains docs-first until that happens.
6. The default page mapper emits deterministic Searchlight-ready records with
   preserved document and page attribution.
7. Runtime tests prove extracted page records can be indexed and queried by a
   real Searchlight database.
8. Persistence tests prove snapshot round-trip and missing/corrupt snapshot
   fallback behavior.
9. BM25 is the default first algorithm used by the runtime and topology proofs.
10. The package docs clearly state:
   - why this is not a `SearchlightPlugin`
   - why this is separate from `searchlight_parsedoc`
   - what Searchlight owns vs what `searchlight_pdf` owns
   - that OCR, viewer widgets, and guaranteed geometry are out of v1
11. V1 public surface is limited to parse APIs, typed models, and the page
   mapper. No convenience population helper ships in v1.
12. Tomekeeper rollout guidance recommends coexistence first and one global
   index plus filters as the initial topology only after measured budgets are
   recorded.
13. The spec defines rollback triggers and dual-path parity checks before
   replacing Tomekeeper’s existing SQLite FTS path.
14. The spec, research docs, README, and implementation plan all align with the
   final v1 public surface and package boundary decisions.
</done_when>
