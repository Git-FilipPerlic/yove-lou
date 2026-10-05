import 'package:flutter_test/flutter_test.dart';

import 'package:yove_lou/src/deck.dart';

void main() {
  group('fmtTime', () {
    test('formats minutes, seconds and tenths', () {
      expect(fmtTime(const Duration(minutes: 3, seconds: 7, milliseconds: 450)), '03:07.4');
    });

    test('drops tenths when asked', () {
      expect(
        fmtTime(const Duration(minutes: 1, seconds: 5, milliseconds: 900), tenths: false),
        '01:05',
      );
    });

    test('shows a minus sign for negative durations (remaining time)', () {
      expect(fmtTime(const Duration(seconds: -65), tenths: false), '-01:05');
    });
  });
}
