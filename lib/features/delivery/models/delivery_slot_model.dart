/// Response model for delivery slot list API
class DeliverySlotListResponse {
  final bool success;
  final String message;
  final DeliverySlotListData? data;

  const DeliverySlotListResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory DeliverySlotListResponse.fromJson(Map<String, dynamic> json) {
    return DeliverySlotListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? DeliverySlotListData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Data wrapper containing count and slots list
class DeliverySlotListData {
  final int count;
  final List<DeliverySlotApiModel> slots;

  const DeliverySlotListData({
    required this.count,
    required this.slots,
  });

  factory DeliverySlotListData.fromJson(Map<String, dynamic> json) {
    return DeliverySlotListData(
      count: json['count'] as int? ?? 0,
      slots: (json['slots'] as List<dynamic>?)
              ?.map((e) => DeliverySlotApiModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Individual delivery slot from API
class DeliverySlotApiModel {
  final String id;
  final String slotStartTime;
  final String slotEndTime;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const DeliverySlotApiModel({
    required this.id,
    required this.slotStartTime,
    required this.slotEndTime,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeliverySlotApiModel.fromJson(Map<String, dynamic> json) {
    return DeliverySlotApiModel(
      id: json['_id'] as String? ?? '',
      slotStartTime: json['slotStartTime'] as String? ?? '',
      slotEndTime: json['slotEndTime'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  /// Get formatted time range (e.g., "8:00 AM - 9:00 AM")
  String get timeRange => '$slotStartTime - $slotEndTime';

  /// Determine slot type based on start time
  String get slotType {
    final hour = _parseHour(slotStartTime);
    if (hour >= 5 && hour < 11) return 'morning';
    if (hour >= 11 && hour < 17) return 'afternoon';
    return 'night';
  }

  /// Get slot display name
  String get slotName {
    switch (slotType) {
      case 'morning':
        return 'Morning Slot';
      case 'afternoon':
        return 'Afternoon Slot';
      case 'night':
        return 'Night Slot';
      default:
        return 'Slot';
    }
  }

  /// Parse hour from time string like "8:00 AM" or "12:00 PM"
  int _parseHour(String time) {
    try {
      final parts = time.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final period = parts.length > 1 ? parts[1].toUpperCase() : '';

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return hour;
    } catch (_) {
      return 0;
    }
  }
}

// ── Confirm Delivery Slot Models ──

/// Request model for confirming delivery slots
class ConfirmDeliverySlotRequest {
  final String deliveryDate;
  final List<ConfirmSlotItem> slots;
  final ConfirmDeliveryAddress deliveryAddress;
  final String paymentMethod;

  const ConfirmDeliverySlotRequest({
    required this.deliveryDate,
    required this.slots,
    required this.deliveryAddress,
    required this.paymentMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      'deliveryDate': deliveryDate,
      'slots': slots.map((s) => s.toJson()).toList(),
      'deliveryAddress': deliveryAddress.toJson(),
      'paymentMethod': paymentMethod,
    };
  }
}

/// Individual slot with selected category IDs
class ConfirmSlotItem {
  final String slotId;
  final List<String> categoryIds;

  const ConfirmSlotItem({
    required this.slotId,
    required this.categoryIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'slotId': slotId,
      'categoryIds': categoryIds,
    };
  }
}

/// Delivery address for confirm request
class ConfirmDeliveryAddress {
  final String buildingName;
  final String street;
  final String pincode;
  final String contactNumber;

  const ConfirmDeliveryAddress({
    required this.buildingName,
    required this.street,
    required this.pincode,
    required this.contactNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'buildingName': buildingName,
      'street': street,
      'pincode': pincode,
      'contactNumber': contactNumber,
    };
  }
}

/// Response model for confirm delivery slots API
class ConfirmDeliverySlotResponse {
  final bool success;
  final String message;

  const ConfirmDeliverySlotResponse({
    required this.success,
    required this.message,
  });

  factory ConfirmDeliverySlotResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmDeliverySlotResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}
