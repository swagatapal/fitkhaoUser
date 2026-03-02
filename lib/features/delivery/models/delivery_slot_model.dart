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

  /// Get formatted time range (e.g., "8:00 AM - 9:00 AM")
  String get timeRange => '$slotStartTime - $slotEndTime';

  /// Determine slot type based on slot name from API
  String get slotType {
    final name = slotName.toLowerCase();
    if (name.contains('morning')) return 'morning';
    if (name.contains('afternoon')) return 'afternoon';
    if (name.contains('night') || name.contains('evening')) return 'night';
    // Fallback to time-based detection
    final hour = _parseHour(slotStartTime);
    if (hour >= 5 && hour < 11) return 'morning';
    if (hour >= 11 && hour < 17) return 'afternoon';
    return 'night';
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
          ? SelectionWindow.fromJson(json['selectionWindow'] as Map<String, dynamic>)
          : const SelectionWindow(start: '18:00', end: '23:59'),
      isWithinWindow: json['isWithinWindow'] as bool? ?? false,
      alreadyConfirmed: json['alreadyConfirmed'] as bool? ?? false,
      previousSelection: (json['previousSelection'] as List<dynamic>?)
              ?.map((e) => PreviousSlotSelection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      availableMeals: (json['availableMeals'] as List<dynamic>?)
              ?.map((e) => AvailableMealCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      slots: (json['slots'] as List<dynamic>?)
              ?.map((e) => DeliverySlotApiModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => SlotHistoryEntry.fromJson(e as Map<String, dynamic>))
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

// ── Slot Booking History Models ──

/// One entry in the 7-day booking history returned by the API
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

  /// Short day name — e.g. "Mon", "Tue"
  String get dayName {
    final date = DateTime.tryParse(deliveryDate);
    if (date == null) return '';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  /// Full day name — e.g. "Monday"
  String get fullDayName {
    final date = DateTime.tryParse(deliveryDate);
    if (date == null) return '';
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  /// Formatted date — e.g. "25 Feb"
  String get formattedDate {
    final date = DateTime.tryParse(deliveryDate);
    if (date == null) return deliveryDate;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  // ── Booking date getters (based on confirmedAt in IST UTC+5:30) ──

  /// confirmedAt converted to Indian Standard Time (UTC+5:30)
  DateTime? get _confirmedAtIST =>
      confirmedAt?.toUtc().add(const Duration(hours: 5, minutes: 30));

  /// Short day name of booking date — e.g. "Mon" (falls back to dayName)
  String get bookingDayName {
    final date = _confirmedAtIST;
    if (date == null) return dayName;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  /// Full day name of booking date — e.g. "Monday" (falls back to fullDayName)
  String get bookingFullDayName {
    final date = _confirmedAtIST;
    if (date == null) return fullDayName;
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  /// Formatted booking date — e.g. "25 Feb" (falls back to formattedDate)
  String get bookingFormattedDate {
    final date = _confirmedAtIST;
    if (date == null) return formattedDate;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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

/// A single slot inside a history entry — uses `_id.slotId` / `_id.categoryIds`
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
