/// A kitchen returned by GET /api/adm/kitchen?isActive=true
class KitchenModel {
  final String id; // _id
  final String name; // kitchenName / name
  final String shortId;
  final bool isActive;

  /// Open/close flag as reported by the kitchen-list payload. The dedicated
  /// open-status endpoint is the authoritative source; this is the fallback.
  final bool isOpen;

  final String? managerName;
  final List<String> serviceablePincodes;

  const KitchenModel({
    required this.id,
    required this.name,
    this.shortId = '',
    this.isActive = true,
    this.isOpen = true,
    this.managerName,
    this.serviceablePincodes = const [],
  });

  factory KitchenModel.fromJson(Map<String, dynamic> json) {
    return KitchenModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['kitchenName'] as String? ?? json['name'] as String? ?? '',
      shortId: json['shortId'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      isOpen: json['isOpen'] as bool? ?? true,
      managerName: json['managerName'] as String?,
      serviceablePincodes: (json['serviceablePincodes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  KitchenModel copyWith({bool? isOpen}) => KitchenModel(
        id: id,
        name: name,
        shortId: shortId,
        isActive: isActive,
        isOpen: isOpen ?? this.isOpen,
        managerName: managerName,
        serviceablePincodes: serviceablePincodes,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is KitchenModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Response wrapper for the kitchen-list endpoint.
class KitchenListResponse {
  final bool success;
  final String message;
  final List<KitchenModel> kitchens;

  const KitchenListResponse({
    required this.success,
    required this.message,
    this.kitchens = const [],
  });

  factory KitchenListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final list = (data?['kitchens'] as List<dynamic>?)
            ?.map((k) => KitchenModel.fromJson(k as Map<String, dynamic>))
            .toList() ??
        const [];
    return KitchenListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      kitchens: list,
    );
  }
}

/// Parsed result of GET /api/adm/kitchen/{kitchenId}/open-status
class KitchenOpenStatus {
  final String kitchenId;
  final bool isOpen;
  final String? reason;

  const KitchenOpenStatus({
    required this.kitchenId,
    required this.isOpen,
    this.reason,
  });

  factory KitchenOpenStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return KitchenOpenStatus(
      kitchenId: data['kitchenId'] as String? ?? '',
      isOpen: data['isOpen'] as bool? ?? true,
      reason: data['reason'] as String?,
    );
  }
}
