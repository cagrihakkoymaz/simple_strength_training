class Exercise {
  const Exercise({
    this.id,
    required this.name,
    required this.currentMax,
    this.active = true,
    this.sortOrder = 0,
  });

  final int? id;
  final String name;

  /// Current Goliaz group (the "Max" column of the table).
  final int currentMax;
  final bool active;
  final int sortOrder;

  Exercise copyWith({int? id, String? name, int? currentMax, bool? active, int? sortOrder}) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        currentMax: currentMax ?? this.currentMax,
        active: active ?? this.active,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'current_max': currentMax,
    'active': active ? 1 : 0,
    'sort_order': sortOrder,
  };

  factory Exercise.fromMap(Map<String, Object?> m) => Exercise(
    id: m['id'] as int?,
    name: m['name'] as String,
    currentMax: m['current_max'] as int,
    active: (m['active'] as int) == 1,
    sortOrder: m['sort_order'] as int,
  );
}
