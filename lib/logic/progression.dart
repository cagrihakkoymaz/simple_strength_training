import '../data/goliaz_table.dart';

/// A group is "unbroken" when every set reached its target.
bool isUnbroken(List<int> targets, List<int> actuals) {
  if (targets.length != actuals.length) return false;
  for (var i = 0; i < targets.length; i++) {
    if (actuals[i] < targets[i]) return false;
  }
  return true;
}

/// Default choice on the finish screen: advance only after an unbroken day.
bool defaultAdvance(List<int> targets, List<int> actuals) =>
    isUnbroken(targets, actuals);

int nextMax(int current, {required bool advance}) {
  final next = advance ? current + 1 : current;
  return next < kTableMinMax ? kTableMinMax : next;
}
