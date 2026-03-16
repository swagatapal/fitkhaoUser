class ExerciseGroup {
  final String id;
  final String exerciseGroup;
  final String description;
  final List<String> exercises;
  final int sortOrder;
  final bool isActive;

  const ExerciseGroup({
    required this.id,
    required this.exerciseGroup,
    required this.description,
    required this.exercises,
    required this.sortOrder,
    required this.isActive,
  });

  /// Lowercase value used for UI state comparison (e.g. 'aerobic', 'strength training')
  String get value => exerciseGroup.toLowerCase();

  factory ExerciseGroup.fromJson(Map<String, dynamic> json) {
    final exercisesList = (json['exercises'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    return ExerciseGroup(
      id: json['_id'] as String? ?? '',
      exerciseGroup: json['exerciseGroup'] as String? ?? '',
      description: json['description'] as String? ?? '',
      exercises: exercisesList,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
