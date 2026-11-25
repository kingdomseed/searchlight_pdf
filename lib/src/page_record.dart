import 'package:searchlight/searchlight.dart';
import 'package:searchlight_pdf/src/page_text.dart';

/// One PDF page as a search record.
final class PdfPageRecord {
  /// Creates a record for [page] of [documentId].
  const PdfPageRecord({
    required this.documentId,
    required this.page,
    required this.text,
  });

  /// Schema for [toSearchlightRecord]; search `text` and `alt`.
  static final schema = Schema({
    'documentId': const TypedField(SchemaType.string),
    'page': const TypedField(SchemaType.number),
    'text': const TypedField(SchemaType.string),
    'alt': const TypedField(SchemaType.string),
  });

  /// The document the page belongs to.
  final String documentId;

  /// Page number, 1-based.
  final int page;

  /// The page's normalized text.
  final PdfPageText text;

  /// Record id, unique across documents.
  String get id => '$documentId#$page';

  /// This page as a record for [schema].
  Map<String, Object?> toSearchlightRecord() => {
    'id': id,
    'documentId': documentId,
    'page': page,
    'text': text.text,
    'alt': text.alt,
  };
}
