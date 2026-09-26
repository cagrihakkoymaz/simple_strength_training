/// Goliaz Strength Training table (source: docs/program_image.jpeg).
///
/// Key = tested max reps ("group"), value = target reps for sets 1–7.
library;

const int kSetsPerGroup = 7;
const int kTableMinMax = 2;
const int kTableMaxMax = 49;

const Map<int, List<int>> goliazTable = {
  2: [1, 1, 1, 1, 1, 1, 1],
  3: [2, 1, 1, 1, 1, 1, 1],
  4: [2, 2, 2, 2, 2, 1, 1],
  5: [2, 2, 2, 2, 2, 2, 1],
  6: [3, 3, 2, 2, 2, 2, 1],
  7: [3, 3, 3, 3, 3, 2, 1],
  8: [3, 4, 3, 3, 3, 2, 2],
  9: [4, 4, 4, 3, 4, 2, 2],
  10: [4, 5, 4, 4, 4, 2, 2],
  11: [5, 5, 4, 4, 4, 3, 3],
  12: [5, 5, 5, 5, 5, 3, 2],
  13: [5, 6, 5, 5, 5, 4, 3],
  14: [6, 6, 6, 5, 6, 4, 2],
  15: [6, 7, 6, 6, 6, 4, 3],
  16: [6, 7, 6, 6, 6, 5, 4],
  17: [7, 8, 7, 6, 7, 5, 3],
  18: [7, 8, 7, 7, 7, 5, 4],
  19: [8, 9, 8, 7, 8, 5, 3],
  20: [8, 9, 8, 8, 8, 6, 3],
  21: [8, 9, 8, 8, 8, 6, 6],
  22: [9, 10, 9, 8, 9, 6, 4],
  23: [9, 10, 9, 9, 9, 6, 6],
  24: [9, 11, 10, 9, 10, 7, 4],
  25: [10, 11, 10, 9, 10, 7, 6],
  26: [10, 12, 10, 10, 10, 7, 6],
  27: [11, 12, 11, 10, 11, 7, 6],
  28: [11, 13, 11, 11, 11, 8, 5],
  29: [11, 13, 12, 11, 12, 8, 6],
  30: [12, 14, 12, 11, 12, 8, 6],
  31: [12, 14, 12, 12, 12, 9, 7],
  32: [12, 14, 13, 12, 13, 9, 7],
  33: [13, 15, 13, 12, 13, 9, 8],
  34: [13, 15, 14, 13, 14, 9, 7],
  35: [14, 16, 14, 13, 14, 10, 7],
  36: [14, 16, 14, 14, 14, 10, 8],
  37: [14, 17, 15, 14, 15, 10, 8],
  38: [15, 17, 15, 14, 15, 10, 9],
  39: [15, 18, 16, 15, 16, 11, 7],
  40: [15, 18, 16, 15, 16, 11, 9],
  41: [16, 18, 16, 15, 16, 11, 11],
  42: [16, 19, 17, 16, 17, 12, 8],
  43: [17, 19, 17, 16, 17, 12, 10],
  44: [17, 20, 18, 17, 18, 12, 8],
  45: [17, 20, 18, 17, 18, 12, 11],
  46: [18, 21, 18, 17, 18, 13, 10],
  47: [18, 21, 19, 18, 19, 13, 10],
  48: [18, 22, 19, 18, 19, 13, 11],
  49: [19, 22, 20, 18, 20, 13, 11],
};

/// Target reps for the 7 sets of [max].
///
/// Below the table it uses the first row; above 49 it scales the last row
/// proportionally (`round(row49[i] * max / 49)`).
List<int> setsForMax(int max) {
  if (max < kTableMinMax) return goliazTable[kTableMinMax]!;
  if (max <= kTableMaxMax) return goliazTable[max]!;
  return goliazTable[kTableMaxMax]!
      .map((reps) => (reps * max / kTableMaxMax).round())
      .toList(growable: false);
}

bool isExtrapolated(int max) => max > kTableMaxMax;
