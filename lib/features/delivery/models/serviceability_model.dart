/// Response model for serviceability check API
class ServiceabilityResponse {
  final bool success;
  final String message;
  final ServiceabilityData? data;

  const ServiceabilityResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ServiceabilityResponse.fromJson(Map<String, dynamic> json) {
    return ServiceabilityResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? ServiceabilityData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Serviceability data
class ServiceabilityData {
  final bool isServiceable;
  final String? zoneName;
  final LocationCoordinates location;
  final List<ServiceableKitchen> kitchens;

  const ServiceabilityData({
    required this.isServiceable,
    this.zoneName,
    required this.location,
    this.kitchens = const [],
  });

  /// Returns the first available kitchen ID, or null if none.
  String? get primaryKitchenId =>
      kitchens.isNotEmpty ? kitchens.first.id : null;

  factory ServiceabilityData.fromJson(Map<String, dynamic> json) {
    final kitchenList = (json['kitchens'] as List<dynamic>?)
            ?.map(
              (k) => ServiceableKitchen.fromJson(k as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return ServiceabilityData(
      isServiceable: json['isServiceable'] as bool? ?? false,
      zoneName: json['zoneName'] as String?,
      location: LocationCoordinates.fromJson(
        (json['location'] as Map<String, dynamic>?) ?? {},
      ),
      kitchens: kitchenList,
    );
  }
}

/// A kitchen returned by the serviceability API
class ServiceableKitchen {
  final String id;
  final String kitchenName;
  final int totalRatings;
  final int totalOrders;

  const ServiceableKitchen({
    required this.id,
    required this.kitchenName,
    this.totalRatings = 0,
    this.totalOrders = 0,
  });

  factory ServiceableKitchen.fromJson(Map<String, dynamic> json) {
    return ServiceableKitchen(
      id: json['_id'] as String? ?? '',
      kitchenName:
          json['kitchenName'] as String? ?? json['name'] as String? ?? '',
      totalRatings: json['totalRatings'] as int? ?? 0,
      totalOrders: json['totalOrders'] as int? ?? 0,
    );
  }
}

/// Location coordinates
class LocationCoordinates {
  final double latitude;
  final double longitude;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });

  factory LocationCoordinates.fromJson(Map<String, dynamic> json) {
    return LocationCoordinates(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
