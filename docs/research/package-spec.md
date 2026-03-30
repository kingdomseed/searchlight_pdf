# Package Spec

## Goal

`searchlight_pdf` should convert PDF content into Searchlight-ready records
without making PDF support a core-package responsibility.

## V1 Responsibilities

- accept PDF input from bytes and/or local files
- extract page text
- preserve document and page attribution metadata
- map extracted output into Searchlight-ready records
- document how app code maps search hits back into a PDF viewer

## V1 Non-Goals

- PDF rendering widgets
- OCR
- guaranteed text geometry APIs
- in-view highlight rendering
- replacing `searchlight_highlight`
- replacing `searchlight_parsedoc`

## Recommended Record Shape

Current root docs point toward a page-level Searchlight shape like:

```dart
{
  'id': 'rules-p12',
  'documentId': 'rules',
  'page': 12,
  'title': 'Rules Reference',
  'content': 'Extracted text from page 12...',
}
```

Additional optional metadata may include:

- `sourcePath`
- `sourceName`
- `pageLabel`
- `section`
- `geometry`

Only schema-declared fields should be relied on for indexing, filtering,
sorting, faceting, or grouping.

## Integration With Other Searchlight Packages

### `searchlight`

Required dependency. `searchlight_pdf` should produce records designed to be
inserted directly into a `Searchlight` database.

### `searchlight_highlight`

Optional companion after search. A common flow is:

1. extract PDF text into records
2. index/search with `searchlight`
3. render snippets or match ranges with `searchlight_highlight`
4. map the selected hit back to a page in the PDF viewer

### `searchlight_parsedoc`

No hard dependency is planned. It remains a separate HTML/Markdown extraction
package. Shared mapping conventions are acceptable where useful, but the PDF
package should not depend on parsedoc to do PDF work.

## Design Principles

- extraction concern, not core-engine concern
- docs-first API design before implementation
- search-first before rendering-first
- preserve attribution and future extension points
- avoid promising geometry or viewer integration until proven

