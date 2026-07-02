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
  final List<TimelineDay> dailyMeals;

  const SubscriptionTimeline({
    this.subscription,
    required this.steps,
    required this.dailyMeals,
  });

  factory SubscriptionTimeline.fromJson(Map<String, dynamic> json) {
    return SubscriptionTimeline(
      subscription: json['subscription'] != null
          ? TimelineSubscription.fromJson(
              json['subscription'] as Map<String, dynamic>)
          : null,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => TimelineStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      dailyMeals: (json['dailyMeals'] as List<dynamic>?)
              ?.map((e) => TimelineDay.fromJson(e as Map<String, dynamic>))
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
  final String slot;
  final String slotTime;
  final TimelineStatus status;

  const TimelineMeal({
    required this.slot,
    required this.slotTime,
    required this.status,
  });

  factory TimelineMeal.fromJson(Map<String, dynamic> json) {
    return TimelineMeal(
      slot: json['slot'] as String? ?? '',
      slotTime: json['slotTime'] as String? ?? '',
      status: TimelineStatus.parse(json['status'] as String?),
    );
  }
}
