part of 'main.dart';

enum _PdfProbeMode {
  openFile('openFile'),
  openData('openData');

  const _PdfProbeMode(this.label);

  final String label;
}

class _PdfProbePageSample {
  const _PdfProbePageSample({
    required this.pageNumber,
    required this.charCount,
    required this.newlineCount,
    required this.elapsedMs,
  });

  final int pageNumber;
  final int charCount;
  final int newlineCount;
  final int elapsedMs;
}

class _PdfProbeReport {
  const _PdfProbeReport({
    required this.mode,
    required this.filePath,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.isEncrypted,
    required this.openElapsedMs,
    required this.pageSamples,
    required this.readElapsedMs,
  });

  final _PdfProbeMode mode;
  final String filePath;
  final int fileSizeBytes;
  final int pageCount;
  final bool isEncrypted;
  final int openElapsedMs;
  final int readElapsedMs;
  final List<_PdfProbePageSample> pageSamples;
}

class _PdfProbeFailure implements Exception {
  const _PdfProbeFailure(this.message, [this.error]);

  final String message;
  final Object? error;

  @override
  String toString() => error == null ? message : '$message\n$error';
}

class _PdfProbe {
  _PdfProbe({required this.cachePath});

  final String cachePath;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const configuredPdfiumPath = _pdfiumPathValue;
    if (configuredPdfiumPath.isNotEmpty &&
        File(configuredPdfiumPath).existsSync()) {
      Pdfrx.loadAsset ??= (name) async {
        throw UnimplementedError(
          'Asset loading is not configured for the probe app: $name',
        );
      };
      Pdfrx.getCacheDirectory ??= () => cachePath;
      Pdfrx.pdfiumModulePath ??= configuredPdfiumPath;
      await PdfrxEntryFunctions.instance.init();
      _initialized = true;
      return;
    }

    await pdfrxInitialize(tmpPath: cachePath);
    _initialized = true;
  }

  Future<_PdfProbeReport> probe({
    required String filePath,
    required _PdfProbeMode mode,
  }) async {
    try {
      await initialize();

      final file = File(filePath);
      if (!file.existsSync()) {
        throw _PdfProbeFailure('File does not exist: $filePath');
      }

      final fileSizeBytes = file.lengthSync();
      return switch (mode) {
        _PdfProbeMode.openFile => _probeOpenFile(
            file: file,
            fileSizeBytes: fileSizeBytes,
          ),
        _PdfProbeMode.openData => _probeOpenData(
            file: file,
            fileSizeBytes: fileSizeBytes,
          ),
      };
    } on Object catch (error) {
      throw _PdfProbeFailure(
        'Probe failed for ${mode.label} on $filePath',
        error,
      );
    }
  }

  Future<_PdfProbeReport> _probeOpenFile({
    required File file,
    required int fileSizeBytes,
  }) async {
    final openWatch = Stopwatch()..start();
    final document = await PdfDocument.openFile(file.path);
    openWatch.stop();

    try {
      return _buildReport(
        mode: _PdfProbeMode.openFile,
        file: file,
        fileSizeBytes: fileSizeBytes,
        readElapsedMs: 0,
        openElapsedMs: openWatch.elapsedMilliseconds,
        document: document,
      );
    } finally {
      await document.dispose();
    }
  }

  Future<_PdfProbeReport> _probeOpenData({
    required File file,
    required int fileSizeBytes,
  }) async {
    final readWatch = Stopwatch()..start();
    final bytes = file.readAsBytesSync();
    readWatch.stop();

    final openWatch = Stopwatch()..start();
    final document = await PdfDocument.openData(
      bytes,
      sourceName: file.uri.toString(),
    );
    openWatch.stop();

    try {
      return _buildReport(
        mode: _PdfProbeMode.openData,
        file: file,
        fileSizeBytes: fileSizeBytes,
        readElapsedMs: readWatch.elapsedMilliseconds,
        openElapsedMs: openWatch.elapsedMilliseconds,
        document: document,
      );
    } finally {
      await document.dispose();
    }
  }

  Future<_PdfProbeReport> _buildReport({
    required _PdfProbeMode mode,
    required File file,
    required int fileSizeBytes,
    required int readElapsedMs,
    required int openElapsedMs,
    required PdfDocument document,
  }) async {
    final pageCount = document.pages.length;
    final samplePages = _samplePageNumbers(pageCount);
    final pageSamples = <_PdfProbePageSample>[];

    for (final pageNumber in samplePages) {
      final page = document.pages[pageNumber - 1];
      final watch = Stopwatch()..start();
      final raw = await page.loadText();
      watch.stop();
      final fullText = raw?.fullText ?? '';
      pageSamples.add(
        _PdfProbePageSample(
          pageNumber: pageNumber,
          charCount: fullText.length,
          newlineCount: '\n'.allMatches(fullText).length,
          elapsedMs: watch.elapsedMilliseconds,
        ),
      );
    }

    return _PdfProbeReport(
      mode: mode,
      filePath: file.path,
      fileSizeBytes: fileSizeBytes,
      pageCount: pageCount,
      isEncrypted: document.isEncrypted,
      openElapsedMs: openElapsedMs,
      readElapsedMs: readElapsedMs,
      pageSamples: pageSamples,
    );
  }

  List<int> _samplePageNumbers(int pageCount) {
    if (pageCount <= 0) {
      return const <int>[];
    }

    final midpoint = max(1, (pageCount / 2).round());
    return SplayTreeSet<int>.of(
      <int>[1, min(2, pageCount), midpoint, pageCount],
    ).toList();
  }
}
