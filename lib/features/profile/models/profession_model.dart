class ProfessionGroup {
  final String id;
  final String professionGroup;
  final String description;
  final List<String> professions;
  final int sortOrder;
  final bool isActive;

  const ProfessionGroup({
    required this.id,
    required this.professionGroup,
    required this.description,
    required this.professions,
    required this.sortOrder,
    required this.isActive,
  });

  /// Lowercase value used for UI state comparison (e.g. 'sedentary', 'moderate', 'heavy')
  String get value => professionGroup.toLowerCase();

  factory ProfessionGroup.fromJson(Map<String, dynamic> json) {
    final professionsList = (json['professions'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    return ProfessionGroup(
      id: json['_id'] as String? ?? '',
      professionGroup: json['professionGroup'] as String? ?? '',
      description: json['description'] as String? ?? '',
      professions: professionsList,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
