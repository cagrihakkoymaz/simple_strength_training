import 'package:flutter_test/flutter_test.dart';
import 'package:simple_strength_training/data/goliaz_table.dart';

void main() {
  test('table has every max from 2 to 49 with 7 sets', () {
    expect(goliazTable.keys, List.generate(48, (i) => i + 2));
    for (final sets in goliazTable.values) {
      expect(sets, hasLength(kSetsPerGroup));
    }
  });

  test('spot-check rows against the image', () {
    expect(setsForMax(2), [1, 1, 1, 1, 1, 1, 1]);
    expect(setsForMax(11), [5, 5, 4, 4, 4, 3, 3]);
    expect(setsForMax(20), [8, 9, 8, 8, 8, 6, 3]);
    expect(setsForMax(21), [8, 9, 8, 8, 8, 6, 6]);
    expect(setsForMax(30), [12, 14, 12, 11, 12, 8, 6]);
    expect(setsForMax(41), [16, 18, 16, 15, 16, 11, 11]);
    expect(setsForMax(49), [19, 22, 20, 18, 20, 13, 11]);
  });

  test('below the table uses the first row', () {
    expect(setsForMax(1), setsForMax(2));
    expect(setsForMax(0), setsForMax(2));
  });

  test('above 49 scales row 49 proportionally', () {
    expect(isExtrapolated(49), isFalse);
    expect(isExtrapolated(50), isTrue);
    // 19,22,20,18,20,13,11 * 60/49
    expect(setsForMax(60), [23, 27, 24, 22, 24, 16, 13]);
    // Never easier than the previous group.
    for (var m = 50; m < 150; m++) {
      final a = setsForMax(m).fold(0, (x, y) => x + y);
      final b = setsForMax(m - 1).fold(0, (x, y) => x + y);
      expect(a, greaterThanOrEqualTo(b), reason: 'max $m');
    }
  });
}
