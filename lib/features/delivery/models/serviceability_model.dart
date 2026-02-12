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
  final LocationCoordinates location;

  const ServiceabilityData({
    required this.isServiceable,
    required this.location,
  });

  factory ServiceabilityData.fromJson(Map<String, dynamic> json) {
    return ServiceabilityData(
      isServiceable: json['isServiceable'] as bool? ?? false,
      location: LocationCoordinates.fromJson(
        json['location'] as Map<String, dynamic>,
      ),
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
