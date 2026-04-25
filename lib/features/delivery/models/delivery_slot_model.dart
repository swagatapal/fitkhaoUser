// Models for Delivery Slot API

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

  const DeliverySlotListData({required this.count, required this.slots});

  factory DeliverySlotListData.fromJson(Map<String, dynamic> json) {
    return DeliverySlotListData(
      count: json['count'] as int? ?? 0,
      slots: (json['slots'] as List<dynamic>?)
              ?.map((e) =>
                  DeliverySlotApiModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Individual delivery slot from API
class DeliverySlotApiModel {
  final String id;
  final String slotName;
  final String slotStartTime;
  final String slotEndTime;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const DeliverySlotApiModel({
    required this.id,
    required this.slotName,
    required this.slotStartTime,
    required this.slotEndTime,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Formatted time range e.g. "8:00 AM - 9:00 AM"
  String get timeRange => '$slotStartTime - $slotEndTime';

  /// Slot type derived from name, then falls back to hour-based detection
  String get slotType {
    final name = slotName.toLowerCase();
    if (name.contains('morning')) return 'morning';
    if (name.contains('afternoon')) return 'afternoon';
    if (name.contains('night') || name.contains('evening')) return 'night';
    final hour = _parseHour(slotStartTime);
    if (hour >= 5 && hour < 11) return 'morning';
    if (hour >= 11 && hour < 17) return 'afternoon';
    return 'night';
  }

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

  factory DeliverySlotApiModel.fromJson(Map<String, dynamic> json) {
    return DeliverySlotApiModel(
      id: json['_id'] as String? ?? '',
      slotName: json['slotName'] as String? ?? '',
      slotStartTime: json['slotStartTime'] as String? ?? '',
      slotEndTime: json['slotEndTime'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

// ── Combined Delivery Slots API (GET /api/delivery-slots?date=) ──

/// Response for the combined delivery slots API
class DeliverySlotsResponse {
  final bool success;
  final String message;
  final DeliverySlotsData? data;

  const DeliverySlotsResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory DeliverySlotsResponse.fromJson(Map<String, dynamic> json) {
    return DeliverySlotsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? DeliverySlotsData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Combined data: slots, meals, previous selections, window info, history
class DeliverySlotsData {
  final String deliveryDate;
  final SelectionWindow selectionWindow;
  final bool isWithinWindow;
  final bool alreadyConfirmed;
  final List<PreviousSlotSelection> previousSelection;
  final List<AvailableMealCategory> availableMeals;
  final List<DeliverySlotApiModel> slots;
  final List<SlotHistoryEntry> history;

  const DeliverySlotsData({
    required this.deliveryDate,
    required this.selectionWindow,
    required this.isWithinWindow,
    required this.alreadyConfirmed,
    required this.previousSelection,
    required this.availableMeals,
    required this.slots,
    this.history = const [],
  });

  factory DeliverySlotsData.fromJson(Map<String, dynamic> json) {
    return DeliverySlotsData(
      deliveryDate: json['deliveryDate'] as String? ?? '',
      selectionWindow: json['selectionWindow'] != null
          ? SelectionWindow.fromJson(
              json['selectionWindow'] as Map<String, dynamic>)
          : const SelectionWindow(start: '18:00', end: '23:59'),
      isWithinWindow: json['isWithinWindow'] as bool? ?? false,
      alreadyConfirmed: json['alreadyConfirmed'] as bool? ?? false,
      previousSelection: (json['previousSelection'] as List<dynamic>?)
              ?.map((e) =>
                  PreviousSlotSelection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      availableMeals: (json['availableMeals'] as List<dynamic>?)
              ?.map((e) =>
                  AvailableMealCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      slots: (json['slots'] as List<dynamic>?)
              ?.map((e) =>
                  DeliverySlotApiModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      history: (json['history'] as List<dynamic>?)
              ?.map(
                  (e) => SlotHistoryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Time window for slot selection
class SelectionWindow {
  final String start;
  final String end;

  const SelectionWindow({required this.start, required this.end});

  factory SelectionWindow.fromJson(Map<String, dynamic> json) {
    return SelectionWindow(
      start: json['start'] as String? ?? '18:00',
      end: json['end'] as String? ?? '23:59',
    );
  }
}

/// Previously confirmed slot selection
class PreviousSlotSelection {
  final String slotId;
  final List<String> categoryIds;

  const PreviousSlotSelection({
    required this.slotId,
    required this.categoryIds,
  });

  factory PreviousSlotSelection.fromJson(Map<String, dynamic> json) {
    return PreviousSlotSelection(
      slotId: json['slotId'] as String? ?? '',
      categoryIds: (json['categoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// Available meal category from the combined API
class AvailableMealCategory {
  final String categoryId;
  final String categoryName;

  const AvailableMealCategory({
    required this.categoryId,
    required this.categoryName,
  });

  factory AvailableMealCategory.fromJson(Map<String, dynamic> json) {
    return AvailableMealCategory(
      categoryId: json['categoryId'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
    );
  }
}

// ── Slot Booking History Models ──

class SlotHistoryEntry {
  final String deliveryDate;
  final String status;
  final DateTime? confirmedAt;
  final List<SlotHistorySlot> slots;

  const SlotHistoryEntry({
    required this.deliveryDate,
    required this.status,
    this.confirmedAt,
    required this.slots,
  });

  bool get isConfirmed => status == 'confirmed' && slots.isNotEmpty;

  String get dayName {
    final date = DateTime.tryParse(deliveryDate);
    if (date == null) return '';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String get formattedDate {
    final date = DateTime.tryParse(deliveryDate);
    if (date == null) return deliveryDate;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  factory SlotHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List<dynamic>? ?? [];
    return SlotHistoryEntry(
      deliveryDate: json['deliveryDate'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.tryParse(json['confirmedAt'] as String)
          : null,
      slots: rawSlots
          .whereType<Map<String, dynamic>>()
          .map(SlotHistorySlot.fromJson)
          .where((s) => s.slotId.isNotEmpty)
          .toList(),
    );
  }
}

class SlotHistorySlot {
  final String slotId;
  final List<String> categoryIds;

  const SlotHistorySlot({required this.slotId, required this.categoryIds});

  factory SlotHistorySlot.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] as Map<String, dynamic>?;
    return SlotHistorySlot(
      slotId: id?['slotId'] as String? ?? '',
      categoryIds: (id?['categoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

// ── Confirm Request / Response ──

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

  Map<String, dynamic> toJson() => {
        'deliveryDate': deliveryDate,
        'slots': slots.map((s) => s.toJson()).toList(),
        'deliveryAddress': deliveryAddress.toJson(),
        'paymentMethod': paymentMethod,
      };
}

class ConfirmSlotItem {
  final String slotId;
  final List<String> categoryIds;

  const ConfirmSlotItem({required this.slotId, required this.categoryIds});

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'categoryIds': categoryIds,
      };
}

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

  Map<String, dynamic> toJson() => {
        'buildingName': buildingName,
        'street': street,
        'pincode': pincode,
        'contactNumber': contactNumber,
      };
}

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
