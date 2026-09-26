import 'package:flutter_test/flutter_test.dart';
import 'package:simple_strength_training/logic/progression.dart';

void main() {
  const targets = [5, 5, 4, 4, 4, 3, 3];

  test('unbroken only when every set reaches target', () {
    expect(isUnbroken(targets, [5, 5, 4, 4, 4, 3, 3]), isTrue);
    expect(isUnbroken(targets, [6, 5, 4, 4, 4, 3, 3]), isTrue);
    expect(isUnbroken(targets, [5, 5, 4, 3, 4, 3, 3]), isFalse);
    expect(isUnbroken(targets, [5, 5, 4]), isFalse);
  });

  test('default is advance on success, stay on failure', () {
    expect(defaultAdvance(targets, [5, 5, 4, 4, 4, 3, 3]), isTrue);
    expect(defaultAdvance(targets, [5, 5, 4, 4, 4, 3, 2]), isFalse);
  });

  test('nextMax', () {
    expect(nextMax(11, advance: true), 12);
    expect(nextMax(11, advance: false), 11);
    expect(nextMax(49, advance: true), 50);
  });
}
