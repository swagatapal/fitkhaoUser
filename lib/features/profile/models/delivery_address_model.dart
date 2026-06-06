/// A user-managed delivery address.
///
/// Mirrors the shape returned by GET /api/user/delivery-addresses and the
/// payload accepted by the create/update endpoints.
class DeliveryAddressModel {
  final String id; // _id (empty for a not-yet-saved address)
  final String label; // home | work | other
  final String buildingName;
  final String street;
  final String area;
  final String city;
  final String pincode;
  final double latitude;
  final double longitude;
  final String floorNumber;
  final String roomNumber;
  final String landmark;
  final String contactNumber;
  final String deliveryInstructions;
  final bool isDefault;

  const DeliveryAddressModel({
    this.id = '',
    this.label = 'home',
    this.buildingName = '',
    this.street = '',
    this.area = '',
    this.city = '',
    this.pincode = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.floorNumber = '',
    this.roomNumber = '',
    this.landmark = '',
    this.contactNumber = '',
    this.deliveryInstructions = '',
    this.isDefault = false,
  });

  factory DeliveryAddressModel.fromJson(Map<String, dynamic> json) {
    return DeliveryAddressModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'home',
      buildingName: json['buildingName'] as String? ?? '',
      street: json['street'] as String? ?? '',
      area: json['area'] as String? ?? '',
      city: json['city'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      floorNumber: json['floorNumber']?.toString() ?? '',
      roomNumber: json['roomNumber']?.toString() ?? '',
      landmark: json['landmark'] as String? ?? '',
      contactNumber: json['contactNumber'] as String? ?? '',
      deliveryInstructions: json['deliveryInstructions'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  /// Request body for create / update. Optional fields are omitted when blank
  /// so the server doesn't store empty strings.
  Map<String, dynamic> toRequestBody() {
    return {
      'buildingName': buildingName,
      'street': street,
      'pincode': pincode,
      'label': label,
      if (area.isNotEmpty) 'area': area,
      if (city.isNotEmpty) 'city': city,
      if (floorNumber.isNotEmpty) 'floorNumber': floorNumber,
      if (roomNumber.isNotEmpty) 'roomNumber': roomNumber,
      if (landmark.isNotEmpty) 'landmark': landmark,
      'contactNumber': contactNumber,
      'latitude': latitude,
      'longitude': longitude,
      if (deliveryInstructions.isNotEmpty)
        'deliveryInstructions': deliveryInstructions,
      'isDefault': isDefault,
    };
  }

  DeliveryAddressModel copyWith({
    String? id,
    String? label,
    String? buildingName,
    String? street,
    String? area,
    String? city,
    String? pincode,
    double? latitude,
    double? longitude,
    String? floorNumber,
    String? roomNumber,
    String? landmark,
    String? contactNumber,
    String? deliveryInstructions,
    bool? isDefault,
  }) {
    return DeliveryAddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      buildingName: buildingName ?? this.buildingName,
      street: street ?? this.street,
      area: area ?? this.area,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      floorNumber: floorNumber ?? this.floorNumber,
      roomNumber: roomNumber ?? this.roomNumber,
      landmark: landmark ?? this.landmark,
      contactNumber: contactNumber ?? this.contactNumber,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// A single-line, human-readable address summary (skips blank parts).
  String get formattedAddress {
    final parts = <String>[
      if (buildingName.isNotEmpty) buildingName,
      if (street.isNotEmpty) street,
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
      if (pincode.isNotEmpty) pincode,
    ];
    return parts.join(', ');
  }
}
