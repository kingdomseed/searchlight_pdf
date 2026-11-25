import 'package:searchlight_pdf/src/page_record.dart';
import 'package:searchlight_pdf/src/page_text.dart';

/// Raw text of a PDF's pages, as a PDF engine extracts it.
///
/// Implement this over the engine the app uses (pdfrx, pdfium, ...). The
/// caller owns the source and closes the document.
abstract interface class PdfTextSource {
  /// Number of pages in the document.
  int get pageCount;

  /// Raw text of page [pageNumber] (1-based); empty for a page without text.
  Future<String> loadPageText(int pageNumber);
}

/// Reads [source] one page at a time from [fromPage] and yields a normalized
/// record per page.
///
/// Only one page's text is held at a time, so long books never sit in memory
/// whole. Cancelling the subscription stops reading.
Stream<PdfPageRecord> readPdfPages(
  PdfTextSource source, {
  required String documentId,
  int fromPage = 1,
}) async* {
  for (var page = fromPage; page <= source.pageCount; page++) {
    final text = normalizePdfPageText(await source.loadPageText(page));
    yield PdfPageRecord(documentId: documentId, page: page, text: text);
  }
}
