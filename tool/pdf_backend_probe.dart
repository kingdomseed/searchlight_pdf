import 'dart:collection';
import 'dart:io';

import 'package:pdfium_dart/pdfium_dart.dart' as pdfium_dart;
import 'package:pdfrx_engine/pdfrx_engine.dart';

Future<void> main(List<String> arguments) async {
  final config = _parseConfig(arguments);
  if (config == null) {
    _printUsage(stderr);
    exitCode = 64;
    return;
  }

  final file = File(config.filePath);
  if (!file.existsSync()) {
    stderr.writeln('Missing file: ${config.filePath}');
    exitCode = 66;
    return;
  }

  stdout
    ..writeln('backend: pdfrx_engine')
    ..writeln('mode: ${config.mode.label}')
    ..writeln('file: ${file.path}');
  _logEnvironment(config);

  try {
    await _initializePdfrx(config);

    final report = await _probeFile(
      file: file,
      mode: config.mode,
    );
    stdout.write(_formatReport(report));
    exitCode = 0;
  } on Object catch (error, stackTrace) {
    stderr
      ..writeln('probeFailure: $error')
      ..writeln(stackTrace);
    exitCode = 1;
  }
}

Future<void> _initializePdfrx(_ProbeConfig config) async {
  final pdfiumPath = config.pdfiumPath;
  if (pdfiumPath != null) {
    final module = File(pdfiumPath);
    if (!module.existsSync()) {
      throw StateError('Configured PDFium module does not exist: $pdfiumPath');
    }

    await _initializeWithResolvedModule(
      config: config,
      module: module,
      initLabel: 'manual',
    );
    return;
  }

  final release = config.pdfiumRelease ?? pdfium_dart.currentPDFiumRelease;
  stdout
    ..writeln('pdfiumRelease: $release')
    ..writeln('pdfiumDownloadUrl: ${_buildDownloadUrl(release)}');
  final resolvedPath = await pdfium_dart.PDFiumDownloader
      .downloadAndGetPDFiumModulePath(
    config.cacheDir.path,
    pdfiumRelease: release,
  );
  await _initializeWithResolvedModule(
    config: config,
    module: File(resolvedPath),
    initLabel: 'downloaded',
  );
}

Future<void> _initializeWithResolvedModule({
  required _ProbeConfig config,
  required File module,
  required String initLabel,
}) async {
  if (!module.existsSync()) {
    throw StateError('Resolved PDFium module does not exist: ${module.path}');
  }

  Pdfrx.loadAsset ??= (name) async {
    throw UnimplementedError('Asset loading is not configured: $name');
  };
  Pdfrx.getCacheDirectory ??= () => config.cacheDir.path;
  Pdfrx.pdfiumModulePath ??= module.path;

  stdout
    ..writeln('init: $initLabel')
    ..writeln('cacheDir: ${config.cacheDir.path}')
    ..writeln('pdfiumPath: ${module.path}')
    ..writeln('pdfiumExists: ${module.existsSync()}')
    ..writeln('pdfiumSizeBytes: ${module.lengthSync()}');
  _logDirectoryContents(module.parent);

  await PdfrxEntryFunctions.instance.init();
  stdout.writeln('initResult: success');
}

void _logEnvironment(_ProbeConfig config) {
  stdout
    ..writeln('platformVersion: ${Platform.version}')
    ..writeln('operatingSystem: ${Platform.operatingSystem}')
    ..writeln('cacheDir: ${config.cacheDir.path}')
    ..writeln('env.PDFIUM_PATH: ${Platform.environment['PDFIUM_PATH'] ?? ''}')
    ..writeln(
      'env.PDFRX_CACHE_DIR: ${Platform.environment['PDFRX_CACHE_DIR'] ?? ''}',
    )
    ..writeln('env.TMPDIR: ${Platform.environment['TMPDIR'] ?? ''}');
}

String _buildDownloadUrl(String release) {
  final platformArch = RegExp(
    '"([^_]+)_([^_]+)"',
  ).firstMatch(Platform.version);
  final platform = platformArch?.group(1) ?? Platform.operatingSystem;
  final arch = platformArch?.group(2) ?? 'unknown';
  final pdfiumPlatform = platform == 'macos' ? 'mac' : platform;
  return 'https://github.com/bblanchon/pdfium-binaries/releases/download/'
      '$release/pdfium-$pdfiumPlatform-$arch.tgz';
}

void _logDirectoryContents(Directory directory) {
  stdout.writeln('pdfiumDir: ${directory.path}');
  final entries = directory
      .listSync(followLinks: false)
      .map((entry) => switch (entry) {
            File() => 'file ${entry.path} (${entry.lengthSync()} bytes)',
            Directory() => 'dir ${entry.path}',
            _ => 'other ${entry.path}',
          })
      .toList()
    ..sort();
  for (final entry in entries) {
    stdout.writeln('pdfiumDirEntry: $entry');
  }
}

Future<_ProbeReport> _probeFile({
  required File file,
  required _ProbeMode mode,
}) async {
  PdfDocument? document;
  var readElapsedMs = 0;

  try {
    switch (mode) {
      case _ProbeMode.openFile:
        final openWatch = Stopwatch()..start();
        document = await PdfDocument.openFile(file.path);
        openWatch.stop();
        return _buildReport(
          file: file,
          mode: mode,
          document: document,
          openElapsedMs: openWatch.elapsedMilliseconds,
          readElapsedMs: readElapsedMs,
        );
      case _ProbeMode.openData:
        final readWatch = Stopwatch()..start();
        final bytes = file.readAsBytesSync();
        readWatch.stop();
        readElapsedMs = readWatch.elapsedMilliseconds;

        final openWatch = Stopwatch()..start();
        document = await PdfDocument.openData(
          bytes,
          sourceName: file.uri.toString(),
        );
        openWatch.stop();

        return _buildReport(
          file: file,
          mode: mode,
          document: document,
          openElapsedMs: openWatch.elapsedMilliseconds,
          readElapsedMs: readElapsedMs,
        );
    }
  } finally {
    await document?.dispose();
  }
}

Future<_ProbeReport> _buildReport({
  required File file,
  required _ProbeMode mode,
  required PdfDocument document,
  required int openElapsedMs,
  required int readElapsedMs,
}) async {
  final pageCount = document.pages.length;
  final pageNumbers = _samplePageNumbers(pageCount);
  final pageSamples = <_PageSample>[];

  for (final pageNumber in pageNumbers) {
    final page = document.pages[pageNumber - 1];
    final watch = Stopwatch()..start();
    final raw = await page.loadText();
    watch.stop();
    final text = raw?.fullText ?? '';
    pageSamples.add(
      _PageSample(
        pageNumber: pageNumber,
        charCount: text.length,
        newlineCount: '\n'.allMatches(text).length,
        loadElapsedMs: watch.elapsedMilliseconds,
      ),
    );
  }

  return _ProbeReport(
    mode: mode,
    filePath: file.path,
    fileSizeBytes: file.lengthSync(),
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

  final midpoint = ((pageCount + 1) / 2).floor();
  return SplayTreeSet<int>.of(<int>[
    1,
    if (pageCount > 1) 2,
    midpoint,
    pageCount,
  ]).toList();
}

String _formatReport(_ProbeReport report) {
  final buffer = StringBuffer()
    ..writeln('result: success')
    ..writeln('pageCount: ${report.pageCount}')
    ..writeln('isEncrypted: ${report.isEncrypted}')
    ..writeln('fileSizeBytes: ${report.fileSizeBytes}')
    ..writeln('readElapsedMs: ${report.readElapsedMs}')
    ..writeln('openElapsedMs: ${report.openElapsedMs}')
    ..writeln('pageSamples:');

  for (final sample in report.pageSamples) {
    buffer.writeln(
      '- page=${sample.pageNumber} '
      'chars=${sample.charCount} '
      'newlines=${sample.newlineCount} '
      'loadTextMs=${sample.loadElapsedMs}',
    );
  }

  return buffer.toString();
}

_ProbeConfig? _parseConfig(List<String> arguments) {
  if (arguments.isEmpty) {
    return null;
  }

  String? filePath;
  String? pdfiumPath;
  String? pdfiumRelease;
  var mode = _ProbeMode.openData;
  Directory? cacheDir;

  for (var index = 0; index < arguments.length; index++) {
    final arg = arguments[index];
    switch (arg) {
      case '--mode':
        final value = _nextValue(arguments, ++index, '--mode');
        if (value == null) {
          return null;
        }
        final parsedMode = _ProbeMode.fromCli(value);
        if (parsedMode == null) {
          return null;
        }
        mode = parsedMode;
      case '--pdfium-path':
        pdfiumPath = _nextValue(arguments, ++index, '--pdfium-path');
        if (pdfiumPath == null) {
          return null;
        }
      case '--pdfium-release':
        pdfiumRelease = _nextValue(arguments, ++index, '--pdfium-release');
        if (pdfiumRelease == null) {
          return null;
        }
      case '--cache-dir':
        final value = _nextValue(arguments, ++index, '--cache-dir');
        if (value == null) {
          return null;
        }
        cacheDir = Directory(value);
      default:
        if (arg.startsWith('--')) {
          return null;
        }
        filePath ??= arg;
    }
  }

  if (filePath == null) {
    return null;
  }

  return _ProbeConfig(
    filePath: filePath,
    mode: mode,
    pdfiumPath: pdfiumPath,
    pdfiumRelease: pdfiumRelease,
    cacheDir:
        cacheDir ?? Directory.systemTemp.createTempSync('searchlight_pdf'),
  );
}

String? _nextValue(List<String> arguments, int index, String flag) {
  if (index >= arguments.length) {
    stderr.writeln('Missing value for $flag');
    return null;
  }
  return arguments[index];
}

void _printUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/pdf_backend_probe.dart <pdf-path> '
    '[--mode openData|openFile] '
    '[--pdfium-path /abs/path/to/libpdfium.dylib] '
    '[--pdfium-release chromium%2F7520] '
    '[--cache-dir /abs/path/to/cache]',
  );
}

class _ProbeConfig {
  const _ProbeConfig({
    required this.filePath,
    required this.mode,
    required this.pdfiumPath,
    required this.pdfiumRelease,
    required this.cacheDir,
  });

  final String filePath;
  final _ProbeMode mode;
  final String? pdfiumPath;
  final String? pdfiumRelease;
  final Directory cacheDir;
}

enum _ProbeMode {
  openData('openData'),
  openFile('openFile');

  const _ProbeMode(this.label);

  final String label;

  static _ProbeMode? fromCli(String value) {
    return switch (value) {
      'openData' => _ProbeMode.openData,
      'openFile' => _ProbeMode.openFile,
      _ => null,
    };
  }
}

class _ProbeReport {
  const _ProbeReport({
    required this.mode,
    required this.filePath,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.isEncrypted,
    required this.openElapsedMs,
    required this.readElapsedMs,
    required this.pageSamples,
  });

  final _ProbeMode mode;
  final String filePath;
  final int fileSizeBytes;
  final int pageCount;
  final bool isEncrypted;
  final int openElapsedMs;
  final int readElapsedMs;
  final List<_PageSample> pageSamples;
}

class _PageSample {
  const _PageSample({
    required this.pageNumber,
    required this.charCount,
    required this.newlineCount,
    required this.loadElapsedMs,
  });

  final int pageNumber;
  final int charCount;
  final int newlineCount;
  final int loadElapsedMs;
}
