import 'dart:ui' show FrameTiming;

import 'package:cerebro_mobile/features/auth/data/current_user_provider.dart';
import 'package:cerebro_mobile/features/documents/data/document.dart';
import 'package:cerebro_mobile/features/documents/data/documents_repository_provider.dart';
import 'package:cerebro_mobile/features/documents/presentation/documents_screen.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/documents/fake_documents_repository.dart';

/// Scroll smoothness of the Documents list on a real device or emulator.
/// Run in profile mode (debug builds are not representative):
///   flutter test integration_test/documents_scroll_perf_test.dart \
///     -d DEVICE --profile
/// Prints the average / worst frame build and raster times (ms) while the
/// list is flung up and down.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flinging the Documents list', (tester) async {
    final docs = [
      for (var i = 0; i < 300; i++)
        DocumentSummary(
          id: 'id-$i',
          title: 'A reasonably long document title number $i.pdf',
          mime: i.isEven ? 'application/pdf' : 'text/markdown',
          sizeBytes: 1024 * (i + 1),
          originalSizeBytes: 1024 * (i + 1),
          status: i % 7 == 0 ? DocumentStatus.sealed : DocumentStatus.ready,
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('perf-user'),
          documentsRepositoryProvider.overrideWithValue(
            FakeDocumentsRepository(documents: docs),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const DocumentsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> t) => timings.addAll(t);
    WidgetsBinding.instance.addTimingsCallback(collect);

    final list = find.byKey(const Key('documents_list'));
    for (var i = 0; i < 6; i++) {
      await tester.fling(list, const Offset(0, -900), 3000);
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 6; i++) {
      await tester.fling(list, const Offset(0, 900), 3000);
      await tester.pumpAndSettle();
    }
    // Timings arrive a little after the frames do.
    await Future<void>.delayed(const Duration(seconds: 1));
    WidgetsBinding.instance.removeTimingsCallback(collect);

    double ms(Duration d) => d.inMicroseconds / 1000;
    final build = [for (final t in timings) ms(t.buildDuration)]..sort();
    final raster = [for (final t in timings) ms(t.rasterDuration)]..sort();
    double avg(List<double> v) =>
        v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
    double p95(List<double> v) => v.isEmpty ? 0 : v[(v.length * 0.95).floor()];
    final over = timings.where((t) => ms(t.totalSpan) > 16.7).length;
    // ignore: avoid_print
    print(
      'PERF frames=${timings.length} '
      'build avg=${avg(build).toStringAsFixed(1)} p95=${p95(build).toStringAsFixed(1)} '
      'worst=${build.isEmpty ? 0 : build.last.toStringAsFixed(1)} | '
      'raster avg=${avg(raster).toStringAsFixed(1)} p95=${p95(raster).toStringAsFixed(1)} '
      'worst=${raster.isEmpty ? 0 : raster.last.toStringAsFixed(1)} | '
      'frames over 16.7ms: $over',
    );
    binding.reportData = {'frames': timings.length};
  });
}
