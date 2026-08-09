// Models for the subscription journey timeline (GET /api/subscriptions/timeline)

/// Lifecycle state shared by timeline steps and daily meals.
enum TimelineStatus {
  completed,
  active,
  pending,
  upcoming,
  rescheduled,
  cancelled,
  unknown;

  static TimelineStatus parse(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'completed':
        return TimelineStatus.completed;
      case 'active':
        return TimelineStatus.active;
      case 'pending':
        return TimelineStatus.pending;
      case 'upcoming':
        return TimelineStatus.upcoming;
      case 'rescheduled':
        return TimelineStatus.rescheduled;
      case 'cancelled':
      case 'canceled':
        return TimelineStatus.cancelled;
      default:
        return TimelineStatus.unknown;
    }
  }

  /// Display label (empty for [unknown]).
  String get label {
    switch (this) {
      case TimelineStatus.completed:
        return 'Completed';
      case TimelineStatus.active:
        return 'Active';
      case TimelineStatus.pending:
        return 'Pending';
      case TimelineStatus.upcoming:
        return 'Upcoming';
      case TimelineStatus.rescheduled:
        return 'Rescheduled';
      case TimelineStatus.cancelled:
        return 'Cancelled';
      case TimelineStatus.unknown:
        return '';
    }
  }
}

class SubscriptionTimelineResponse {
  final bool success;
  final String message;
  final SubscriptionTimeline? data;

  const SubscriptionTimelineResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory SubscriptionTimelineResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionTimelineResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? SubscriptionTimeline.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SubscriptionTimeline {
  final TimelineSubscription? subscription;
  final List<TimelineStep> steps;

  /// Meal-plan phases, one per service period (`mealPlanNumber` → Service
  /// Period N). Each phase carries its own date window and daily meals.
  final List<MealPlanPhase> mealPlanOrders;

  const SubscriptionTimeline({
    this.subscription,
    required this.steps,
    required this.mealPlanOrders,
  });

  /// All scheduled days flattened across every phase (chronological order is
  /// preserved as returned by the API).
  List<TimelineDay> get allDays => [
        for (final phase in mealPlanOrders) ...phase.dailyMeals,
      ];

  /// The phase whose `mealPlanNumber` matches [number] (i.e. Service Period N),
  /// or null when no such phase exists yet.
  MealPlanPhase? phaseForNumber(int number) {
    for (final phase in mealPlanOrders) {
      if (phase.mealPlanNumber == number) return phase;
    }
    return null;
  }

  factory SubscriptionTimeline.fromJson(Map<String, dynamic> json) {
    // New shape: `mealPlanOrders` (list of phases). Legacy shape: a flat
    // `dailyMeals` list at the top level → wrap it in a single phase (#1).
    List<MealPlanPhase> phases;
    final rawPhases = json['mealPlanOrders'] as List<dynamic>?;
    if (rawPhases != null) {
      phases = rawPhases
          .whereType<Map<String, dynamic>>()
          .map(MealPlanPhase.fromJson)
          .toList();
    } else {
      final legacyDays = (json['dailyMeals'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(TimelineDay.fromJson)
              .toList() ??
          const <TimelineDay>[];
      phases = legacyDays.isEmpty
          ? const []
          : [MealPlanPhase(mealPlanNumber: 1, dailyMeals: legacyDays)];
    }

    return SubscriptionTimeline(
      subscription: json['subscription'] != null
          ? TimelineSubscription.fromJson(
              json['subscription'] as Map<String, dynamic>)
          : null,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => TimelineStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      mealPlanOrders: phases,
    );
  }
}

/// One meal-plan phase = one service period. `mealPlanNumber` 1 → "Service
/// Period 1", 2 → "Service Period 2", and so on.
class MealPlanPhase {
  final int mealPlanNumber;
  final DateTime? phaseStart;
  final DateTime? phaseEnd;
  final List<TimelineDay> dailyMeals;

  const MealPlanPhase({
    required this.mealPlanNumber,
    this.phaseStart,
    this.phaseEnd,
    required this.dailyMeals,
  });

  factory MealPlanPhase.fromJson(Map<String, dynamic> json) {
    return MealPlanPhase(
      mealPlanNumber: (json['mealPlanNumber'] as num?)?.toInt() ?? 0,
      phaseStart: DateTime.tryParse(json['phaseStart'] as String? ?? ''),
      phaseEnd: DateTime.tryParse(json['phaseEnd'] as String? ?? ''),
      dailyMeals: (json['dailyMeals'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(TimelineDay.fromJson)
              .toList() ??
          const [],
    );
  }
}

class TimelineSubscription {
  final String id;
  final String planName;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int remainingDays;

  const TimelineSubscription({
    required this.id,
    required this.planName,
    required this.status,
    this.startDate,
    this.endDate,
    required this.remainingDays,
  });

  factory TimelineSubscription.fromJson(Map<String, dynamic> json) {
    return TimelineSubscription(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startDate: DateTime.tryParse(json['startDate'] as String? ?? ''),
      endDate: DateTime.tryParse(json['endDate'] as String? ?? ''),
      remainingDays: (json['remainingDays'] as num?)?.toInt() ?? 0,
    );
  }
}

class TimelineStep {
  final String key;
  final String name;
  final TimelineStatus status;
  final DateTime? date;

  const TimelineStep({
    required this.key,
    required this.name,
    required this.status,
    this.date,
  });

  factory TimelineStep.fromJson(Map<String, dynamic> json) {
    return TimelineStep(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: TimelineStatus.parse(json['status'] as String?),
      date: DateTime.tryParse(json['date'] as String? ?? ''),
    );
  }
}

class TimelineDay {
  final String date; // raw "YYYY-MM-DD"
  final List<TimelineMeal> meals;

  const TimelineDay({required this.date, required this.meals});

  /// Parsed date-only [DateTime] (null if unparseable).
  DateTime? get parsedDate {
    final p = DateTime.tryParse(date);
    return p == null ? null : DateTime(p.year, p.month, p.day);
  }

  factory TimelineDay.fromJson(Map<String, dynamic> json) {
    return TimelineDay(
      date: json['date'] as String? ?? '',
      meals: (json['meals'] as List<dynamic>?)
              ?.map((e) => TimelineMeal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class TimelineMeal {
  final String orderId;
  final String orderNumber;
  final String slot;
  final String slotTime;
  final String statusRaw; // e.g. "confirmed"
  final TimelineStatus status;

  const TimelineMeal({
    this.orderId = '',
    this.orderNumber = '',
    required this.slot,
    required this.slotTime,
    this.statusRaw = '',
    required this.status,
  });

  /// Display label — falls back to the raw status when it isn't a known
  /// timeline status (e.g. "Confirmed").
  String get statusLabel {
    if (status.label.isNotEmpty) return status.label;
    if (statusRaw.isEmpty) return '';
    final w = statusRaw.replaceAll('_', ' ');
    return '${w[0].toUpperCase()}${w.substring(1)}';
  }

  /// A slot/address change or cancellation is possible only while the order is
  /// still ahead of delivery.
  bool get isActionable {
    if (orderId.isEmpty) return false;
    const blocked = {
      'delivered',
      'cancelled',
      'canceled',
      'failed',
      'rejected',
      'out_for_delivery',
    };
    return !blocked.contains(statusRaw.toLowerCase());
  }

  factory TimelineMeal.fromJson(Map<String, dynamic> json) {
    return TimelineMeal(
      orderId: json['orderId'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      slot: json['slot'] as String? ?? '',
      slotTime: json['slotTime'] as String? ?? '',
      statusRaw: json['status'] as String? ?? '',
      status: TimelineStatus.parse(json['status'] as String?),
    );
  }
}
