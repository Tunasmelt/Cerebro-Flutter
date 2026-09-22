// Milestone 0.5 proof: this test is deliberately wrong. It exists only
// to confirm CI actually blocks a PR with a failing test — deleted once
// that's confirmed, never meant to be merged.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deliberately fails to prove CI blocks a bad PR', () {
    expect(1 + 1, 3);
  });
}
