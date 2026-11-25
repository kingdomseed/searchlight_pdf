# Searchlight PDF

Turns PDF page text into [Searchlight](https://github.com/kingdomseed/searchlight)-ready
page records. Pure Dart: the app extracts text with the PDF engine it already
uses and passes it in through `PdfTextSource`.

## What it does

PDF engines return text with quirks that break word search. `normalizePdfPageText`
fixes the ones seen in real rulebooks:

- pdfium marks a word split across a line with U+0002 (`ele` U+0002 `ments`),
  and some PDFs use a soft hyphen (U+00AD). The word is rejoined (`elements`),
  and both parts go into `alt`, so `grid` still finds `grid-based`.
- Letter-spaced headings (`C O M B A T`) become one word (`COMBAT`).
- Ligatures (`ﬁ`, `ﬃ`) are expanded and curly apostrophes become `'`.
- Line breaks, tabs, non-breaking and other spaces, and control characters
  become single spaces.

The result keeps a map back to the raw text, so a match in the normalized text
can be mapped to the engine's character boxes for highlighting:

```dart
final page = normalizePdfPageText(rawText);
final at = page.text.indexOf('elements');
final raw = page.rawRange(at, at + 'elements'.length);
// raw.start and raw.end index the engine's text and character boxes.
```

## Indexing a PDF

Implement `PdfTextSource` over your engine, then read pages one at a time.
Only one page's text is held at a time, so long books never sit in memory
whole.

```dart
final class PdfrxTextSource implements PdfTextSource {
  PdfrxTextSource(this.document);

  final PdfDocument document;

  @override
  int get pageCount => document.pages.length;

  @override
  Future<String> loadPageText(int pageNumber) async =>
      (await document.pages[pageNumber - 1].loadText())?.fullText ?? '';
}

final db = Searchlight.create(schema: PdfPageRecord.schema);
await for (final record in readPdfPages(source, documentId: 'rules')) {
  db.insert(record.toSearchlightRecord());
}
final hits = db.search(term: 'elements', properties: const ['text', 'alt']);
```

`fromPage` resumes reading after an interruption. The records also work with
other indexes, such as SQLite FTS5: store `text` and `alt` in two columns.

## Not included

OCR (scanned PDFs have no text to extract), rendering, viewer widgets, and
match highlighting, which belongs to the app or `searchlight_highlight`.

## Background

- [`docs/research/package-spec.md`](docs/research/package-spec.md): package scope
- [`docs/research/library-evaluation.md`](docs/research/library-evaluation.md):
  why extraction stays outside the package
- [`docs/research/current-understanding.md`](docs/research/current-understanding.md)
