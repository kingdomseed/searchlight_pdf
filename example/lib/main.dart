import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';

part 'pdf_probe.dart';

const _autorunModeValue = String.fromEnvironment('PDF_PROBE_AUTORUN');
const _autorunPathValue = String.fromEnvironment('PDF_PROBE_PATH');
const _pdfiumPathValue = String.fromEnvironment('PDF_PROBE_PDFIUM_PATH');

void main() {
  runApp(const _SearchlightPdfProbeApp());
}

class _SearchlightPdfProbeApp extends StatelessWidget {
  const _SearchlightPdfProbeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Searchlight PDF Probe',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: const Color(0xFF0B5D4B)),
      ),
      home: const _ProbeHomePage(),
    );
  }
}

class _ProbeHomePage extends StatefulWidget {
  const _ProbeHomePage();

  @override
  State<_ProbeHomePage> createState() => _ProbeHomePageState();
}

class _ProbeHomePageState extends State<_ProbeHomePage> {
  late final _PdfProbe _probe;
  late final List<_BenchmarkTarget> _targets;

  String? _selectedPath;
  String _status = 'Choose a benchmark and run a probe.';
  bool _isRunning = false;
  _PdfProbeReport? _lastReport;
  String? _lastFailure;

  @override
  void initState() {
    super.initState();
    _probe = _PdfProbe(cachePath: Directory.systemTemp.path);
    _targets = _defaultTargets();
    _selectedPath = _initialSelection();
    _scheduleAutorunIfConfigured();
  }

  List<_BenchmarkTarget> _defaultTargets() {
    final repoRoot = Directory.current.parent.path;
    final targets = <_BenchmarkTarget>[
      _BenchmarkTarget(
        label: 'Smoke: Mythic quick reference',
        path: '$repoRoot/tmp/pdf-corpus-local/smoke/mythic-gme-2e-quick-reference.pdf',
      ),
      _BenchmarkTarget(
        label: 'Smoke: Mythic magazine index',
        path: '$repoRoot/tmp/pdf-corpus-local/smoke/mythic-magazine-index.pdf',
      ),
      _BenchmarkTarget(
        label: 'Medium: Nimble basic rules',
        path: '$repoRoot/tmp/pdf-corpus-local/medium/nimble-basic-rules.pdf',
      ),
    ];
    if (_autorunPathValue.isNotEmpty &&
        targets.every((target) => target.path != _autorunPathValue)) {
      targets.add(
        _BenchmarkTarget(
          label: 'Custom: ${File(_autorunPathValue).uri.pathSegments.last}',
          path: _autorunPathValue,
        ),
      );
    }
    return targets;
  }

  Future<void> _runProbe(_PdfProbeMode mode) async {
    final selectedPath = _selectedPath;
    if (selectedPath == null) {
      setState(() {
        _status = 'No file selected.';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _lastFailure = null;
      _lastReport = null;
      _status = 'Running ${mode.label} for $selectedPath';
    });

    try {
      final report = await _probe.probe(filePath: selectedPath, mode: mode);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastReport = report;
        _status = 'Probe completed: ${mode.label}';
      });
      debugPrint(_formatReport(report));
    } on _PdfProbeFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastFailure = error.toString();
        _status = 'Probe failed: ${mode.label}';
      });
      debugPrint(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Searchlight PDF Backend Probe'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              'Probe `pdfrx_engine` directly from the `searchlight_pdf` repo.',
              style: theme.textTheme.titleMedium,
            ),
            DropdownButtonFormField<String>(
              initialValue: _selectedPath,
              decoration: const InputDecoration(
                labelText: 'Benchmark PDF',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final target in _targets)
                  DropdownMenuItem<String>(
                    value: target.path,
                    child: Text(target.label),
                  ),
              ],
              onChanged: _isRunning
                  ? null
                  : (value) {
                      setState(() {
                        _selectedPath = value;
                      });
                    },
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runProbe(_PdfProbeMode.openData),
                  child: const Text('Probe openData'),
                ),
                OutlinedButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runProbe(_PdfProbeMode.openFile),
                  child: const Text('Probe openFile'),
                ),
              ],
            ),
            SelectableText(
              _status,
              style: theme.textTheme.bodyMedium,
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F3EC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCFD4CF)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _ProbeOutput(
                    report: _lastReport,
                    failure: _lastFailure,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _initialSelection() {
    if (_autorunPathValue.isNotEmpty) {
      return _autorunPathValue;
    }
    return _targets.isEmpty ? null : _targets.first.path;
  }

  void _scheduleAutorunIfConfigured() {
    final autorunMode = _parseAutorunMode();
    if (autorunMode == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runProbe(autorunMode));
    });
  }

  _PdfProbeMode? _parseAutorunMode() {
    return switch (_autorunModeValue) {
      'openFile' => _PdfProbeMode.openFile,
      'openData' => _PdfProbeMode.openData,
      _ => null,
    };
  }
}

class _ProbeOutput extends StatelessWidget {
  const _ProbeOutput({
    required this.report,
    required this.failure,
  });

  final _PdfProbeReport? report;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (failure case final failure?) {
      return SelectableText(
        failure,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    if (report case final report?) {
      final buffer = StringBuffer()
        ..writeln('mode: ${report.mode.label}')
        ..writeln('file: ${report.filePath}')
        ..writeln('sizeBytes: ${report.fileSizeBytes}')
        ..writeln('pageCount: ${report.pageCount}')
        ..writeln('isEncrypted: ${report.isEncrypted}')
        ..writeln('readElapsedMs: ${report.readElapsedMs}')
        ..writeln('openElapsedMs: ${report.openElapsedMs}')
        ..writeln()
        ..writeln('pageSamples:');

      for (final sample in report.pageSamples) {
        buffer.writeln(
          '- page ${sample.pageNumber}: '
          'chars=${sample.charCount} '
          'newlines=${sample.newlineCount} '
          'loadTextMs=${sample.elapsedMs}',
        );
      }

      return SelectableText(
        buffer.toString(),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
        ),
      );
    }

    return SelectableText(
      'No probe run yet.',
      style: theme.textTheme.bodyMedium,
    );
  }
}

class _BenchmarkTarget {
  const _BenchmarkTarget({
    required this.label,
    required this.path,
  });

  final String label;
  final String path;
}

String _formatReport(_PdfProbeReport report) {
  final buffer = StringBuffer()
    ..writeln('mode: ${report.mode.label}')
    ..writeln('file: ${report.filePath}')
    ..writeln('sizeBytes: ${report.fileSizeBytes}')
    ..writeln('pageCount: ${report.pageCount}')
    ..writeln('isEncrypted: ${report.isEncrypted}')
    ..writeln('readElapsedMs: ${report.readElapsedMs}')
    ..writeln('openElapsedMs: ${report.openElapsedMs}')
    ..writeln()
    ..writeln('pageSamples:');

  for (final sample in report.pageSamples) {
    buffer.writeln(
      '- page ${sample.pageNumber}: '
      'chars=${sample.charCount} '
      'newlines=${sample.newlineCount} '
      'loadTextMs=${sample.elapsedMs}',
    );
  }

  return buffer.toString();
}
