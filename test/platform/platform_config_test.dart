// Guards native platform config that no Dart test exercises and no debug
// build can reveal. Each check here corresponds to a real failure that was
// invisible until a different build type or platform was inspected.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Android', () {
    test(
      'the MAIN manifest declares INTERNET — Flutter adds it only to the '
      'debug/profile manifests, so without this a RELEASE build cannot '
      'reach the network (no sign-in, no API calls, no uploads)',
      () {
        final main = _read('android/app/src/main/AndroidManifest.xml');
        expect(
          main,
          contains('<uses-permission android:name="android.permission.INTERNET"'),
        );
      },
    );

    test('the camera flow stays intent-based: no CAMERA permission declared', () {
      // image_picker's camera path uses the system camera app, which needs
      // no permission. Declaring CAMERA would force a runtime prompt (and
      // a denial path) onto a flow that doesn't otherwise need one.
      final main = _read('android/app/src/main/AndroidManifest.xml');
      expect(main, isNot(contains('android.permission.CAMERA')));
    });
  });

  group('iOS', () {
    final plist = _read('ios/Runner/Info.plist');

    test('has the camera and photo-library usage strings the pickers need', () {
      // iOS terminates the app on first use of either without these.
      expect(plist, contains('NSCameraUsageDescription'));
      expect(plist, contains('NSPhotoLibraryUsageDescription'));
    });

    test('deployment target is at least 14.0, which file_picker 13 requires', () {
      final project = _read('ios/Runner.xcodeproj/project.pbxproj');
      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = (\d+)\.')
          .allMatches(project)
          .map((m) => int.parse(m.group(1)!))
          .toList();
      expect(targets, isNotEmpty);
      expect(targets.every((v) => v >= 14), isTrue, reason: '$targets');

      final framework = _read('ios/Flutter/AppFrameworkInfo.plist');
      final min = RegExp(r'MinimumOSVersion</key>\s*<string>(\d+)\.')
          .firstMatch(framework);
      expect(int.parse(min!.group(1)!), greaterThanOrEqualTo(14));
    });
  });
}
