// Models for consultation booking (nutritionists, slots, booking).

String _str(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    final v = j[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    if (v is num) return v.toString();
  }
  return '';
}

// ── Nutritionists (GET /api/user/nutritionists) ──

class Nutritionist {
  final String id;
  final String name;
  final List<String> specializations;
  final int yearsOfExperience;
  final String bio;
  final int totalConsultations;
  final int totalRatings;
  final String currentStatus;

  const Nutritionist({
    required this.id,
    required this.name,
    required this.specializations,
    required this.yearsOfExperience,
    required this.bio,
    required this.totalConsultations,
    required this.totalRatings,
    required this.currentStatus,
  });

  bool get isAvailable => currentStatus.toLowerCase() == 'available';

  /// "General • Weight management" from raw snake_case specialization codes.
  String get specializationLabel => specializations
      .map((s) => s
          .split('_')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' '))
      .join(' • ');

  factory Nutritionist.fromJson(Map<String, dynamic> json) {
    return Nutritionist(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: _str(json, ['name', 'fullName']),
      specializations: (json['specializations'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt() ?? 0,
      bio: json['bio'] as String? ?? '',
      totalConsultations: (json['totalConsultations'] as num?)?.toInt() ?? 0,
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      currentStatus: json['currentStatus'] as String? ?? '',
    );
  }
}

class NutritionistsResponse {
  final bool success;
  final String message;
  final List<Nutritionist> nutritionists;

  const NutritionistsResponse({
    required this.success,
    required this.message,
    required this.nutritionists,
  });

  factory NutritionistsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<dynamic> raw = const [];
    if (data is Map<String, dynamic>) {
      raw = (data['nutritionists'] ?? data['items'] ?? const []) as List;
    } else if (data is List) {
      raw = data;
    }
    return NutritionistsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      nutritionists: raw
          .whereType<Map<String, dynamic>>()
          .map(Nutritionist.fromJson)
          .toList(),
    );
  }
}

// ── Slots (GET /api/adm/nutritionist/{id}/slots?date=) ──
//
// The exact envelope isn't documented, so parsing tolerates several shapes:
// data may be an availability object, a list of them, or a wrapper holding the
// list; each availability carries the id sent back as `availabilityId`, and its
// time entries carry the id sent as `consultationTimeId`.

/// A single bookable time slot.
///
/// The slots endpoint returns each slot as `{_id, fromTime, toTime, isActive,
/// isOccupied, booking}`. The booking API wants `availabilityId` +
/// `consultationTimeId`: [id] is the slot `_id` (consultationTimeId) and
/// [availabilityId] is the parent availability id when the response carries one,
/// otherwise it falls back to the slot's own `_id`.
class ConsultationTime {
  final String id; // → consultationTimeId (slot _id)
  final String availabilityId; // → availabilityId
  final String fromTime;
  final String toTime;
  final bool isBooked;

  const ConsultationTime({
    required this.id,
    required this.availabilityId,
    required this.fromTime,
    required this.toTime,
    required this.isBooked,
  });

  String get label {
    if (fromTime.isEmpty) return toTime;
    if (toTime.isEmpty) return fromTime;
    return '$fromTime - $toTime';
  }

  factory ConsultationTime.fromJson(
    Map<String, dynamic> json, {
    required String availabilityId,
  }) {
    final status =
        (json['status'] ?? json['slotStatus'] ?? '').toString().toLowerCase();
    final booked = json['isOccupied'] == true ||
        json['isBooked'] == true ||
        json['booked'] == true ||
        json['booking'] != null ||
        json['isActive'] == false ||
        json['isAvailable'] == false ||
        status == 'booked' ||
        status == 'occupied' ||
        status == 'unavailable';
    final id = json['_id'] as String? ??
        json['id'] as String? ??
        json['consultationTimeId'] as String? ??
        '';
    return ConsultationTime(
      id: id,
      // No parent availability id in the response → book against the slot id.
      availabilityId: availabilityId.isNotEmpty
          ? availabilityId
          : (json['availabilityId'] as String? ?? id),
      fromTime: _str(json, ['fromTime', 'startTime', 'from', 'start', 'time']),
      toTime: _str(json, ['toTime', 'endTime', 'to', 'end']),
      isBooked: booked,
    );
  }
}

class ConsultationAvailability {
  final String availabilityId;
  final String date; // raw "YYYY-MM-DD"
  final List<ConsultationTime> times;

  const ConsultationAvailability({
    required this.availabilityId,
    required this.date,
    required this.times,
  });

  factory ConsultationAvailability.fromData(Map<String, dynamic> data) {
    final availabilityId = data['availabilityId'] as String? ??
        data['_id'] as String? ??
        data['id'] as String? ??
        '';
    final rawSlots = (data['slots'] ??
        data['consultationTimes'] ??
        data['times'] ??
        data['timeSlots']) as List<dynamic>?;
    return ConsultationAvailability(
      availabilityId: availabilityId,
      date: _str(data, ['date', 'availabilityDate', 'slotDate']),
      times: rawSlots
              ?.whereType<Map<String, dynamic>>()
              .map((s) =>
                  ConsultationTime.fromJson(s, availabilityId: availabilityId))
              .where((t) => t.id.isNotEmpty)
              .toList() ??
          const [],
    );
  }
}

class NutritionistSlotsResponse {
  final bool success;
  final String message;
  final List<ConsultationAvailability> availabilities;

  const NutritionistSlotsResponse({
    required this.success,
    required this.message,
    required this.availabilities,
  });

  /// All bookable time slots flattened across availabilities.
  List<ConsultationTime> get times =>
      [for (final a in availabilities) ...a.times];

  factory NutritionistSlotsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final availabilities = <ConsultationAvailability>[];

    if (data is Map<String, dynamic>) {
      final inner = data['availabilities'] ?? data['availability'];
      if (inner is List) {
        availabilities.addAll(inner
            .whereType<Map<String, dynamic>>()
            .map(ConsultationAvailability.fromData));
      } else {
        // Flat shape: data holds `slots` directly.
        availabilities.add(ConsultationAvailability.fromData(data));
      }
    } else if (data is List) {
      availabilities.addAll(data
          .whereType<Map<String, dynamic>>()
          .map(ConsultationAvailability.fromData));
    }

    return NutritionistSlotsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      availabilities: availabilities.where((a) => a.times.isNotEmpty).toList(),
    );
  }
}

// ── Booking ──

/// Result of POST /api/user/consultations/book-slot.
class BookSlotResponse {
  final bool success;
  final String message;
  final String consultationId;

  const BookSlotResponse({
    required this.success,
    required this.message,
    required this.consultationId,
  });

  factory BookSlotResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    String id = '';
    if (data is Map<String, dynamic>) {
      id = data['consultationId'] as String? ??
          data['_id'] as String? ??
          data['id'] as String? ??
          '';
    }
    return BookSlotResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      consultationId: id,
    );
  }
}

/// The user's current consultation, derived from `data.currentConsultation`
/// of GET /api/user/consultations/active-subscription.
class BookedSlotInfo {
  final String consultationId;
  final String nutritionistId;
  final String status;
  final String nutritionistName;
  final String date; // "YYYY-MM-DD"
  final String fromTime;
  final String toTime;
  final String rescheduleReason;
  final String rescheduleRequestedBy;
  final String meetingLink;

  const BookedSlotInfo({
    required this.consultationId,
    required this.nutritionistId,
    required this.status,
    required this.nutritionistName,
    required this.date,
    required this.fromTime,
    required this.toTime,
    this.rescheduleReason = '',
    this.rescheduleRequestedBy = '',
    this.meetingLink = '',
  });

  bool get hasMeetingLink => meetingLink.trim().isNotEmpty;

  /// A slot is actually booked once its consultation is `scheduled` (the API
  /// leaves it `pending` until a time is chosen; cancelled/completed free it).
  /// A `reschedule_requested` / `rescheduled` consultation still occupies a
  /// slot, so it also counts as booked.
  bool get isBooked {
    const booked = {
      'scheduled',
      'confirmed',
      'booked',
      'reschedule_requested',
      'rescheduled',
    };
    return booked.contains(status.toLowerCase());
  }

  /// The nutritionist (or user) asked to move this consultation to a new time.
  bool get isRescheduleRequested =>
      status.toLowerCase() == 'reschedule_requested';

  /// Human-readable status, e.g. "reschedule_requested" → "Reschedule requested".
  String get statusLabel {
    if (status.isEmpty) return '';
    final words = status.replaceAll('_', ' ').split(' ');
    return words
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String get timeRange {
    if (fromTime.isEmpty) return toTime;
    if (toTime.isEmpty) return fromTime;
    return '$fromTime - $toTime';
  }

  factory BookedSlotInfo.fromCurrentConsultation(Map<String, dynamic> c) {
    final slot = c['slot'] as Map<String, dynamic>?;
    final nutritionist = c['nutritionist'] as Map<String, dynamic>?;
    return BookedSlotInfo(
      consultationId: c['_id'] as String? ?? c['id'] as String? ?? '',
      nutritionistId: c['nutritionistId'] as String? ??
          nutritionist?['_id'] as String? ??
          '',
      status: c['status'] as String? ?? '',
      nutritionistName: _str(nutritionist ?? const {}, ['name', 'fullName']),
      date: _str(c, ['scheduledDateStr', 'scheduledDate', 'date']),
      fromTime: _str(slot ?? const {}, ['fromTime', 'startTime', 'from']),
      toTime: _str(slot ?? const {}, ['toTime', 'endTime', 'to']),
      rescheduleReason: c['rescheduleRequestReason'] as String? ?? '',
      rescheduleRequestedBy: c['rescheduleRequestedBy'] as String? ?? '',
      meetingLink: _str(c, ['meetingLink', 'meetLink', 'meetingUrl', 'link']),
    );
  }
}

/// GET /api/user/consultations/active-subscription — carries the current
/// consultation (if any) for the user's active subscription.
class ActiveConsultationResponse {
  final bool success;
  final String message;
  final BookedSlotInfo? current;

  const ActiveConsultationResponse({
    required this.success,
    required this.message,
    this.current,
  });

  factory ActiveConsultationResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final cc = data?['currentConsultation'] as Map<String, dynamic>?;
    return ActiveConsultationResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      current: cc == null ? null : BookedSlotInfo.fromCurrentConsultation(cc),
    );
  }
}
