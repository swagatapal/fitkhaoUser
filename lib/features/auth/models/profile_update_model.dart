import 'dart:math';

import '../../../core/config/app_config.dart';
import 'auth_state.dart';

class ProfileUpdateRequest {
  final String? name;
  final int? age;
  final String? gender; // male|female
  final double? weight; // kg
  final double? height; // cm
  final String? selectedGoal; // e.g., fat-loss | maintenance
  final bool? doesWorkout;
  final int? workoutDaysPerWeek;
  final double? workoutHoursPerDay;
  final String? exerciseType; // type-1 | type-2 etc
  final String? profession; // optional
  final Address? address;
  final SpecialConditions? specialConditions;
  final DigestiveIssues? digestiveIssues;
  final String? selectedKitchenId;
  final String? imgUrl; // Profile image URL

  const ProfileUpdateRequest({
    this.name,
    this.age,
    this.gender,
    this.weight,
    this.height,
    this.selectedGoal,
    this.doesWorkout,
    this.workoutDaysPerWeek,
    this.workoutHoursPerDay,
    this.exerciseType,
    this.profession ,
    this.address,
    this.specialConditions,
    this.digestiveIssues,
    this.selectedKitchenId,
    this.imgUrl,
  });

  /// Map regularityStatus to DigestiveIssues
  static DigestiveIssues _mapRegularityStatusToDigestiveIssues(String status) {
    final lower = status.toLowerCase();

    if (lower.contains('both') || (lower.contains('constipat') && lower.contains('diarrh'))) {
      return const DigestiveIssues(
        regularlyConstipated: true,
        diarrhoeal: true,
        none: false,
        both: true,
      );
    } else if (lower.contains('constipat')) {
      return const DigestiveIssues(
        regularlyConstipated: true,
        diarrhoeal: false,
        none: false,
        both: false,
      );
    } else if (lower.contains('diarrh')) {
      return const DigestiveIssues(
        regularlyConstipated: false,
        diarrhoeal: true,
        none: false,
        both: false,
      );
    }

    // Default: None
    return const DigestiveIssues(
      regularlyConstipated: false,
      diarrhoeal: false,
      none: true,
      both: false,
    );
  }

  factory ProfileUpdateRequest.fromAuthState(AuthState s) {
    int? computedAge;
    if (s.dateOfBirth != null) {
      final now = DateTime.now();
      int years = now.year - s.dateOfBirth!.year;
      final hasHadBirthdayThisYear = (now.month > s.dateOfBirth!.month) ||
          (now.month == s.dateOfBirth!.month && now.day >= s.dateOfBirth!.day);
      if (!hasHadBirthdayThisYear) years -= 1;
      computedAge = max(0, years);
    }

    final special = SpecialConditions(
      diabetes: s.diabetes,
      hyperTension: s.hypertension,
      cardiacProblem: s.cardiacProblem,
      liverIssues: s.liverRelatedProblem,
      kidneyIssues: s.kidneyDisease,
      none: !(s.diabetes || s.hypertension || s.cardiacProblem || s.liverRelatedProblem || s.kidneyDisease),
      other: (s.otherConditions).trim(),
    );

    // Map regularityStatus to digestiveIssues
    final digestive = _mapRegularityStatusToDigestiveIssues(s.regularityStatus);

    final addr = Address(
      buildingName: s.buildingNameNumber.isNotEmpty ? s.buildingNameNumber : null,
      street: s.street.isNotEmpty ? s.street : null,
      area: s.street.isNotEmpty ? s.street : null, // Using street as area fallback
      city: '', // Default city
      state: '', // Default state
      pincode: s.pincode.isNotEmpty ? s.pincode : null,
      latitude: s.latitude,
      longitude: s.longitude,
    );

    return ProfileUpdateRequest(
      name: s.name.isNotEmpty ? s.name : null,
      age: computedAge,
      gender: s.gender.isNotEmpty ? s.gender : null,
      weight: s.weight,
      height: s.height,
      selectedGoal: "regular-bmi-maintenance", // This is the user's goal (fat-loss, lean-mass-gain, etc)
      doesWorkout: s.doesExercise,
      workoutDaysPerWeek: s.exerciseDaysPerWeek,
      workoutHoursPerDay: s.exerciseDurationHours,
      exerciseType: s.exerciseType, // Already in API format (type-1, type-2, type-3)
      profession: null, // Same as selectedGoal - represents activity level (type-1, type-2, type-3)
      address: addr,
      specialConditions: special,
      digestiveIssues: digestive,
      selectedKitchenId: '', // Empty string as default
      imgUrl: s.imgUrl != null && s.imgUrl!.isNotEmpty ? s.imgUrl : null,
    );
  }

  Map<String, dynamic> toJson() => toFullJson();

  /// Always include all fields as backend expects full object.
  /// - Strings default to ""
  /// - Numbers default to 0
  /// - Booleans default to false
  /// - Objects include all nested keys with their defaults
  Map<String, dynamic> toFullJson() {
    return {
      'name': name ?? '',
      'age': age ?? 0,
      'gender': gender ?? '',
      'weight': weight ?? 0,
      'height': height ?? 0,
      'selectedGoal': selectedGoal ?? '',
      'doesWorkout': doesWorkout ?? false,
      'workoutDaysPerWeek': workoutDaysPerWeek ?? 0,
      'workoutHoursPerDay': workoutHoursPerDay ?? 0,
      'exerciseType': exerciseType ?? '',
      'profession': profession ?? 'type-1',
      'address': (address ?? const Address()).toFullJson(),
      'specialConditions': (specialConditions ?? const SpecialConditions(
        diabetes: false,
        hyperTension: false,
        cardiacProblem: false,
        liverIssues: false,
        kidneyIssues: false,
        none: false,
        other: '',
      )).toFullJson(),
      'digestiveIssues': (digestiveIssues ?? const DigestiveIssues(
        regularlyConstipated: false,
        diarrhoeal: false,
        none: false,
        both: false,
      )).toFullJson(),
      'selectedKitchenId': selectedKitchenId ?? '',
      'imgUrl': imgUrl ?? '',
    };
  }
}

class Address {
  final String? buildingName;
  final String? street;
  final String? area;
  final String? city;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;

  const Address({
    this.buildingName,
    this.street,
    this.area,
    this.city,
    this.state,
    this.pincode,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => toFullJson();

  Map<String, dynamic> toFullJson() {
    return {
      'buildingName': buildingName ?? '',
      'street': street ?? '',
      'area': area ?? '',
      'city': city ?? '',
      'state': state ?? '',
      'pincode': pincode ?? '',
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
    };
  }
}

class SpecialConditions {
  final bool diabetes;
  final bool hyperTension;
  final bool cardiacProblem;
  final bool liverIssues;
  final bool kidneyIssues;
  final bool none;
  final String other;

  const SpecialConditions({
    required this.diabetes,
    required this.hyperTension,
    required this.cardiacProblem,
    required this.liverIssues,
    required this.kidneyIssues,
    required this.none,
    required this.other,
  });

  Map<String, dynamic> toJson() => toFullJson();

  Map<String, dynamic> toFullJson() {
    return {
      'diabetes': diabetes,
      'hyperTension': hyperTension,
      'cardiacProblem': cardiacProblem,
      'liverIssues': liverIssues,
      'kidneyIssues': kidneyIssues,
      'none': none,
      'other': other,
    };
  }
}

class DigestiveIssues {
  final bool regularlyConstipated;
  final bool diarrhoeal;
  final bool none;
  final bool both;

  const DigestiveIssues({
    required this.regularlyConstipated,
    required this.diarrhoeal,
    required this.none,
    required this.both,
  });

  Map<String, dynamic> toJson() => toFullJson();

  Map<String, dynamic> toFullJson() {
    return {
      'regularlyConstipated': regularlyConstipated,
      'diarrhoeal': diarrhoeal,
      'none': none,
      'both': both,
    };
  }
}
