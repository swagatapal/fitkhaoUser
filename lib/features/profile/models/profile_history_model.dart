class ProfileHistory {
  final String id;
  final String userId;
  final String updatedByRole;
  final String source;
  final ProfileHistoryChanges changes;
  final DateTime createdAt;

  const ProfileHistory({
    required this.id,
    required this.userId,
    required this.updatedByRole,
    required this.source,
    required this.changes,
    required this.createdAt,
  });

  factory ProfileHistory.fromJson(Map<String, dynamic> json) {
    return ProfileHistory(
      id: json['_id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      updatedByRole: json['updatedByRole'] as String? ?? 'user',
      source: json['source'] as String? ?? '',
      changes: ProfileHistoryChanges.fromJson(
        json['changes'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ProfileHistoryChanges {
  final String? professionGroupId;
  final List<HistoryExerciseEntry> exercises;
  final double? targetKCalories;
  final double? targetProtein;
  final double? targetFat;
  final double? targetCarbs;
  final HistoryDigestiveIssues? digestiveIssues;
  final List<HistorySpecialCondition> specialConditions;

  const ProfileHistoryChanges({
    this.professionGroupId,
    this.exercises = const [],
    this.targetKCalories,
    this.targetProtein,
    this.targetFat,
    this.targetCarbs,
    this.digestiveIssues,
    this.specialConditions = const [],
  });

  factory ProfileHistoryChanges.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'] as List<dynamic>? ?? [];
    final rawConditions = json['specialConditions'] as List<dynamic>? ?? [];

    return ProfileHistoryChanges(
      professionGroupId: json['professionGroupId'] as String?,
      exercises: rawExercises
          .whereType<Map<String, dynamic>>()
          .map(HistoryExerciseEntry.fromJson)
          .toList(),
      targetKCalories: (json['targetKCalories'] as num?)?.toDouble(),
      targetProtein: (json['targetProtein'] as num?)?.toDouble(),
      targetFat: (json['targetFat'] as num?)?.toDouble(),
      targetCarbs: (json['targetCarbs'] as num?)?.toDouble(),
      digestiveIssues: json['digestiveIssues'] != null
          ? HistoryDigestiveIssues.fromJson(
              json['digestiveIssues'] as Map<String, dynamic>)
          : null,
      specialConditions: rawConditions
          .whereType<Map<String, dynamic>>()
          .map(HistorySpecialCondition.fromJson)
          .toList(),
    );
  }

  /// Returns only active (value=true) special condition codes
  List<String> get activeConditionCodes => specialConditions
      .where((c) => c.value)
      .map((c) => c.code)
      .toList();

  /// Human-readable digestive status
  String get digestiveStatus {
    final d = digestiveIssues;
    if (d == null) return 'None';
    if (d.both) return 'Both';
    if (d.regularlyConstipated) return 'Constipated';
    if (d.regularlyDiarrhoeal) return 'Diarrhoeal';
    return 'None';
  }

  bool get hasNutritionalData =>
      targetKCalories != null ||
      targetProtein != null ||
      targetFat != null ||
      targetCarbs != null;
}

class HistoryExerciseEntry {
  final String exerciseGroupId;
  final int daysPerWeek;
  final double hoursPerDay;

  const HistoryExerciseEntry({
    required this.exerciseGroupId,
    required this.daysPerWeek,
    required this.hoursPerDay,
  });

  factory HistoryExerciseEntry.fromJson(Map<String, dynamic> json) {
    return HistoryExerciseEntry(
      exerciseGroupId: json['exerciseGroupId'] as String? ?? '',
      daysPerWeek: (json['daysPerWeek'] as num?)?.toInt() ?? 0,
      hoursPerDay: (json['hoursPerDay'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HistoryDigestiveIssues {
  final bool regularlyConstipated;
  final bool regularlyDiarrhoeal;
  final bool none;
  final bool both;

  const HistoryDigestiveIssues({
    required this.regularlyConstipated,
    required this.regularlyDiarrhoeal,
    required this.none,
    required this.both,
  });

  factory HistoryDigestiveIssues.fromJson(Map<String, dynamic> json) {
    return HistoryDigestiveIssues(
      regularlyConstipated: json['regularlyConstipated'] as bool? ?? false,
      regularlyDiarrhoeal: json['regularlyDiarrhoeal'] as bool? ?? false,
      none: json['none'] as bool? ?? true,
      both: json['both'] as bool? ?? false,
    );
  }
}

class HistorySpecialCondition {
  final String code;
  final bool value;

  const HistorySpecialCondition({required this.code, required this.value});

  factory HistorySpecialCondition.fromJson(Map<String, dynamic> json) {
    return HistorySpecialCondition(
      code: json['code'] as String? ?? '',
      value: json['value'] as bool? ?? false,
    );
  }
}
