// Models for weekly delivery-slot preferences (/api/user/weekly-delivery-slots)

/// The seven weekdays in the API's canonical order (sunday → saturday), with
/// display labels. `wire` is the lowercase value the API accepts.
class Weekday {
  final String wire;
  final String label;
  const Weekday(this.wire, this.label);

  static const List<Weekday> all = [
    Weekday('sunday', 'Sunday'),
    Weekday('monday', 'Monday'),
    Weekday('tuesday', 'Tuesday'),
    Weekday('wednesday', 'Wednesday'),
    Weekday('thursday', 'Thursday'),
    Weekday('friday', 'Friday'),
    Weekday('saturday', 'Saturday'),
  ];
}

/// One slot assignment within a day: a delivery slot, the meal categories it
/// serves and the address to deliver them to. Carries populated display fields
/// when they come back from GET.
class WeeklySlotAssignment {
  final String slotId;
  final List<String> categoryIds;
  final String deliveryAddressId;

  // Populated (GET only) — used for display, may be empty on a fresh model.
  final String slotName;
  final String slotStartTime;
  final String slotEndTime;
  final List<PopulatedCategory> categories;
  final String addressLabel;
  final String addressSummary;

  const WeeklySlotAssignment({
    required this.slotId,
    required this.categoryIds,
    required this.deliveryAddressId,
    this.slotName = '',
    this.slotStartTime = '',
    this.slotEndTime = '',
    this.categories = const [],
    this.addressLabel = '',
    this.addressSummary = '',
  });

  String get slotTimeRange {
    if (slotStartTime.isEmpty) return slotEndTime;
    if (slotEndTime.isEmpty) return slotStartTime;
    return '$slotStartTime - $slotEndTime';
  }

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'categoryIds': categoryIds,
        'deliveryAddressId': deliveryAddressId,
      };

  factory WeeklySlotAssignment.fromJson(Map<String, dynamic> json) {
    final slot = json['slot'] as Map<String, dynamic>?;
    final address = json['deliveryAddress'] as Map<String, dynamic>?;
    final cats = (json['categories'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(PopulatedCategory.fromJson)
            .toList() ??
        const [];
    return WeeklySlotAssignment(
      slotId: json['slotId'] as String? ?? slot?['_id'] as String? ?? '',
      categoryIds: (json['categoryIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          cats.map((c) => c.id).toList(),
      deliveryAddressId: json['deliveryAddressId'] as String? ??
          address?['_id'] as String? ??
          '',
      slotName: slot?['slotName'] as String? ?? '',
      slotStartTime: slot?['slotStartTime'] as String? ?? '',
      slotEndTime: slot?['slotEndTime'] as String? ?? '',
      categories: cats,
      addressLabel: address?['label'] as String? ?? '',
      addressSummary: _addressSummary(address),
    );
  }

  static String _addressSummary(Map<String, dynamic>? a) {
    if (a == null) return '';
    final parts = <String>[
      for (final k in ['buildingName', 'street', 'area', 'city', 'pincode'])
        if ((a[k] as String?)?.isNotEmpty == true) a[k] as String,
    ];
    return parts.join(', ');
  }
}

class PopulatedCategory {
  final String id;
  final String name;
  const PopulatedCategory({required this.id, required this.name});

  factory PopulatedCategory.fromJson(Map<String, dynamic> json) =>
      PopulatedCategory(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        name: json['dishCategory'] as String? ?? json['name'] as String? ?? '',
      );
}

/// A day and its slot assignments (empty list = no delivery that day).
class WeeklyDaySlots {
  final String day; // wire value (lowercase)
  final List<WeeklySlotAssignment> slots;

  const WeeklyDaySlots({required this.day, required this.slots});

  factory WeeklyDaySlots.fromJson(Map<String, dynamic> json) {
    return WeeklyDaySlots(
      day: (json['day'] as String? ?? '').toLowerCase(),
      slots: (json['slots'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(WeeklySlotAssignment.fromJson)
              .toList() ??
          const [],
    );
  }
}

class WeeklyDeliverySlotsResponse {
  final bool success;
  final String message;
  final List<WeeklyDaySlots> days;

  const WeeklyDeliverySlotsResponse({
    required this.success,
    required this.message,
    required this.days,
  });

  /// Whether the user has ever saved a preference (drives POST vs PUT).
  bool get hasPreference => days.any((d) => d.slots.isNotEmpty);

  factory WeeklyDeliverySlotsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final raw = (data is Map<String, dynamic>
        ? data['weeklyDeliverySlots']
        : data) as List<dynamic>?;
    return WeeklyDeliverySlotsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      days: raw
              ?.whereType<Map<String, dynamic>>()
              .map(WeeklyDaySlots.fromJson)
              .toList() ??
          const [],
    );
  }
}
