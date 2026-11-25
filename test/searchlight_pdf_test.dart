import 'package:searchlight/searchlight.dart';
import 'package:searchlight_pdf/searchlight_pdf.dart';
import 'package:test/test.dart';

final class _ListSource implements PdfTextSource {
  _ListSource(this.pages);

  final List<String> pages;
  final loaded = <int>[];

  @override
  int get pageCount => pages.length;

  @override
  Future<String> loadPageText(int pageNumber) async {
    loaded.add(pageNumber);
    return pages[pageNumber - 1];
  }
}

void main() {
  group('normalizePdfPageText', () {
    test('rejoins a word pdfium split across a line', () {
      final page = normalizePdfPageText('the ele\u0002\r\nments of magic');

      expect(page.text, 'the elements of magic');
      expect(page.alt, 'ele ments');
    });

    test('rejoins a hyphenated compound and keeps its parts as terms', () {
      final page = normalizePdfPageText('a grid\u0002based map');

      expect(page.text, 'a gridbased map');
      expect(page.alt, 'grid based');
    });

    test('keeps every split part of a word broken twice', () {
      final page = normalizePdfPageText('non\u0002player\u0002character');

      expect(page.text, 'nonplayercharacter');
      expect(page.alt, 'non player nonplayer character');
    });

    test('rejoins a word split by a soft hyphen and drops a stray one', () {
      final page = normalizePdfPageText(
        'co\u00ADoperate ele\u00AD\nments 4\u00AD2',
      );

      expect(page.text, 'cooperate elements 42');
      expect(page.alt, 'co operate ele ments');
    });

    test('treats a hyphen mark between non-letters as a space', () {
      expect(normalizePdfPageText('me\u00028 d\u000212').text, 'me 8 d 12');
    });

    test('collapses letter-spaced capitals', () {
      expect(
        normalizePdfPageText(
          'A D V E N T U R O U S\r\nC O M M U N I T Y Rules',
        ).text,
        'ADVENTUROUS COMMUNITY Rules',
      );
    });

    test('leaves short runs of single capitals alone', () {
      expect(normalizePdfPageText('roll A B C').text, 'roll A B C');
    });

    test('expands ligatures and straightens apostrophes', () {
      expect(
        normalizePdfPageText('e\uFB03cient spell\u2019s \uFB01re').text,
        "efficient spell's fire",
      );
    });

    test('collapses line breaks, odd spaces and control characters', () {
      expect(
        normalizePdfPageText(
          '  Oracle.\r\n\u008a You\u00a0ask\t the\u2009GM \r\n',
        ).text,
        'Oracle. You ask the GM',
      );
    });

    test('returns empty text for a page without text', () {
      final page = normalizePdfPageText(' \r\n ');

      expect(page.text, isEmpty);
      expect(page.alt, isEmpty);
      expect(page.rawRange(0, 0), (start: 0, end: 0));
    });

    test('maps a range in the normalized text back to the raw text', () {
      const raw = 'The ele\u0002\r\nments, e\uFB03cient';
      final page = normalizePdfPageText(raw);

      final elements = page.text.indexOf('elements');
      final range = page.rawRange(elements, elements + 'elements'.length);
      expect(raw.substring(range.start, range.end), 'ele\u0002\r\nments');

      final efficient = page.text.indexOf('efficient');
      final lig = page.rawRange(efficient, efficient + 'efficient'.length);
      expect(raw.substring(lig.start, lig.end), 'e\uFB03cient');
    });
  });

  group('readPdfPages', () {
    test('reads one page at a time from the given page', () async {
      final source = _ListSource(['one', 'two', 'thr\u0002ee', 'four']);

      final records = await readPdfPages(
        source,
        documentId: 'rules',
        fromPage: 2,
      ).take(2).toList();

      expect(
        [for (final r in records) (r.id, r.page, r.text.text)],
        [('rules#2', 2, 'two'), ('rules#3', 3, 'three')],
      );
      expect(source.loaded, [2, 3]);
    });

    test('records index into Searchlight and find rejoined words', () async {
      final db = Searchlight.create(schema: PdfPageRecord.schema);
      final source = _ListSource([
        'Chapter one',
        'The ele\u0002\r\nments of a grid\u0002based map',
      ]);
      await for (final record in readPdfPages(source, documentId: 'rules')) {
        db.insert(record.toSearchlightRecord());
      }

      List<String> pagesFor(String term) => [
        for (final hit
            in db.search(term: term, properties: const ['text', 'alt']).hits)
          hit.id,
      ];
      expect(pagesFor('elements'), ['rules#2']);
      expect(pagesFor('grid'), ['rules#2']);
    });
  });
}
