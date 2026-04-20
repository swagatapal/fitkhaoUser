class PhysiologicalCategory {
  final String id;
  final String code;
  final String name;
  final String description;
  final bool isActive;

  const PhysiologicalCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.isActive,
  });

  factory PhysiologicalCategory.fromJson(Map<String, dynamic> json) {
    return PhysiologicalCategory(
      id: json['_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
