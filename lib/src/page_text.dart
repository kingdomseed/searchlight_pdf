import 'dart:typed_data';

/// A page's text normalized for search, with a map back to the raw text.
final class PdfPageText {
  PdfPageText._(this.text, this.alt, this._rawOffsets);

  /// Normalized text: words rejoined, whitespace collapsed.
  final String text;

  /// Extra search terms that are not in [text]: the two parts of each word
  /// rejoined across a hyphen, so `grid` still finds `grid-based`.
  final String alt;

  // Raw index of each code unit of [text].
  final Int32List _rawOffsets;

  /// The raw-text range that the [text] range [start, end) came from.
  ///
  /// Use it to map a match in [text] back to the engine's character boxes.
  ({int start, int end}) rawRange(int start, int end) {
    RangeError.checkValidRange(start, end, text.length);
    if (start == end) {
      final raw = start < _rawOffsets.length
          ? _rawOffsets[start]
          : (_rawOffsets.isEmpty ? 0 : _rawOffsets.last + 1);
      return (start: raw, end: raw);
    }
    return (start: _rawOffsets[start], end: _rawOffsets[end - 1] + 1);
  }
}

// pdfium writes U+0002 where a word breaks across a hyphen.
const _hyphenMark = 0x02;
const _space = 0x20;

const _ligatures = {
  0xFB00: 'ff',
  0xFB01: 'fi',
  0xFB02: 'fl',
  0xFB03: 'ffi',
  0xFB04: 'ffl',
  0xFB05: 'st',
  0xFB06: 'st',
};

/// Normalizes raw PDF page text for search.
///
/// - Rejoins words split across a line by a hyphen (`ele-` `ments` becomes
///   `elements`) and keeps both parts in [PdfPageText.alt].
/// - Collapses letter-spaced capitals (`C O M B A T` becomes `COMBAT`).
/// - Expands ligatures and turns curly apostrophes into `'`.
/// - Turns line breaks, tabs, non-breaking and other spaces, and control
///   characters into single spaces, and trims the ends.
PdfPageText normalizePdfPageText(String raw) {
  final out = <int>[];
  final offsets = <int>[];
  final alt = StringBuffer();
  var wordStart = 0;
  // Output index where the second part of a rejoined word starts.
  int? joinAt;

  void endWord() {
    final join = joinAt;
    if (join != null) {
      alt
        ..write(String.fromCharCodes(out, wordStart, join))
        ..write(' ')
        ..write(String.fromCharCodes(out, join))
        ..write(' ');
      joinAt = null;
    }
  }

  void emitSpace(int rawIndex) {
    endWord();
    if (out.isNotEmpty && out.last != _space) {
      out.add(_space);
      offsets.add(rawIndex);
    }
    wordStart = out.length;
  }

  for (var i = 0; i < raw.length; i++) {
    final c = raw.codeUnitAt(i);
    if (c == _hyphenMark) {
      var next = i + 1;
      while (next < raw.length && _isSpace(raw.codeUnitAt(next))) {
        next++;
      }
      if (out.isNotEmpty &&
          _isLetter(out.last) &&
          next < raw.length &&
          _isLetter(raw.codeUnitAt(next))) {
        if (joinAt != null) endWord();
        joinAt = out.length;
        i = next - 1;
      } else {
        emitSpace(i);
      }
    } else if (_isSpace(c)) {
      emitSpace(i);
    } else if (_ligatures[c] case final expansion?) {
      for (final unit in expansion.codeUnits) {
        out.add(unit);
        offsets.add(i);
      }
    } else {
      out.add(c == 0x2019 || c == 0x2018 || c == 0x02BC ? 0x27 : c);
      offsets.add(i);
      if (!_isLetter(c) && !_isDigit(c)) {
        endWord();
        wordStart = out.length;
      }
    }
  }
  endWord();
  if (out.isNotEmpty && out.last == _space) {
    out.removeLast();
    offsets.removeLast();
  }
  _collapseLetterSpacing(raw, out, offsets);
  return PdfPageText._(
    String.fromCharCodes(out),
    alt.toString().trimRight(),
    Int32List.fromList(offsets),
  );
}

/// Removes the spaces in runs of four or more single capitals.
void _collapseLetterSpacing(String raw, List<int> out, List<int> offsets) {
  var write = 0;
  var i = 0;
  while (i < out.length) {
    final runEnd = _letterSpacedRunEnd(raw, out, offsets, i);
    if (runEnd != null) {
      for (var j = i; j < runEnd; j += 2) {
        out[write] = out[j];
        offsets[write] = offsets[j];
        write++;
      }
      i = runEnd - 1;
    } else {
      out[write] = out[i];
      offsets[write] = offsets[i];
      write++;
    }
    i++;
  }
  out.length = write;
  offsets.length = write;
}

/// The end (exclusive) of a letter-spaced run starting at [start], if any.
///
/// A run continues only across one plain space in the raw text, so two
/// letter-spaced headings on separate lines stay two words.
int? _letterSpacedRunEnd(
  String raw,
  List<int> out,
  List<int> offsets,
  int start,
) {
  if (start > 0 && out[start - 1] != _space) return null;
  var letters = 0;
  var i = start;
  while (i < out.length && _isUpper(out[i])) {
    if (i + 1 < out.length && out[i + 1] != _space) break;
    letters++;
    final continues =
        i + 2 < out.length &&
        offsets[i + 2] - offsets[i] == 2 &&
        raw.codeUnitAt(offsets[i + 1]) == _space;
    i += 2;
    if (!continues) break;
  }
  return letters >= 4 ? i - 1 : null;
}

bool _isSpace(int c) =>
    c <= 0x20 ||
    (c >= 0x7F && c <= 0xA0) ||
    (c >= 0x2000 && c <= 0x200B) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000 ||
    c == 0xFEFF;

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isLetter(int c) {
  if (c < 0x80) return (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7A;
  if (c >= 0xD800 && c <= 0xDFFF) return false;
  final s = String.fromCharCode(c);
  return s.toLowerCase() != s.toUpperCase();
}

bool _isUpper(int c) {
  if (c < 0x80) return c >= 0x41 && c <= 0x5A;
  if (!_isLetter(c)) return false;
  final s = String.fromCharCode(c);
  return s == s.toUpperCase();
}
