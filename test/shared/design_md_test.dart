import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// DESIGN.md is generated (`dart tool/generate_design_md.dart`). If a token or a
/// shared widget is added, renamed or removed without re-running it, these fail.
void main() {
  final design = File('DESIGN.md').readAsStringSync();

  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  Iterable<String> constantNames(String path) => RegExp(
    r'^\s*static const (?:[\w<>]+ )?(\w+) =',
    multiLine: true,
  ).allMatches(read(path)).map((m) => m.group(1)!);

  test('every colour, spacing and radius token is documented', () {
    for (final file in [
      'lib/shared/tokens/app_colors.dart',
      'lib/shared/tokens/app_spacing.dart',
      'lib/shared/tokens/app_radius.dart',
      'lib/shared/tokens/app_motion.dart',
    ]) {
      for (final name in constantNames(file)) {
        // The BorderRadius helpers (smRadius ...) are derived from the radii.
        if (name.endsWith('Radius')) continue;
        expect(
          design,
          contains('`$name`'),
          reason:
              '$name from $file is missing: re-run '
              '`dart tool/generate_design_md.dart`',
        );
      }
    }
  });

  test('every public shared widget is documented', () {
    final widgets = Directory(
      'lib/shared/widgets',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    var found = 0;
    for (final f in widgets) {
      for (final m in RegExp(
        r'^class (\w+) extends \w*Widget',
        multiLine: true,
      ).allMatches(read(f.path))) {
        final name = m.group(1)!;
        if (name.startsWith('_')) continue;
        found++;
        expect(
          design,
          contains('`$name`'),
          reason:
              '$name is missing: re-run `dart tool/generate_design_md.dart`',
        );
      }
    }
    expect(found, greaterThan(8), reason: 'the scan found too few widgets');
  });

  test('the rules DESIGN.md states are the ones the tests enforce', () {
    for (final path in [
      'test/shared/app_colors_test.dart',
      'test/shared/app_contrast_test.dart',
      'test/qa/screens_qa_test.dart',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path is cited');
      expect(design, contains(path));
    }
  });
}
