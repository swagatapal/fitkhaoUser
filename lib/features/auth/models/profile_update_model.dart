import 'dart:math';

import '../../profile/models/physiological_category_model.dart';
import 'auth_state.dart';

class ProfileUpdateRequest {
  final String? name;
  final String? email;
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
  final List<Map<String, dynamic>>? specialConditions;
  final DigestiveIssues? digestiveIssues;
  final String? selectedKitchenId;
  final String? imgUrl; // Profile image URL
  final bool isUpdateable;

  const ProfileUpdateRequest({
    this.name,
    this.email,
    this.age,
    this.gender,
    this.weight,
    this.height,
    this.selectedGoal,
    this.doesWorkout,
    this.workoutDaysPerWeek,
    this.workoutHoursPerDay,
    this.exerciseType,
    this.profession,
    this.address,
    this.specialConditions,
    this.digestiveIssues,
    this.selectedKitchenId,
    this.imgUrl,
    this.isUpdateable = false,
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

  /// Build specialConditions array from selected codes and available categories
  static List<Map<String, dynamic>> _buildSpecialConditionsArray(
    List<String> selectedCodes,
    List<PhysiologicalCategory> availableCategories,
  ) {
    // If we have available categories, build from them
    if (availableCategories.isNotEmpty) {
      return availableCategories.map((cat) {
        return {
          'code': cat.code,
          'value': selectedCodes.contains(cat.code),
        };
      }).toList();
    }

    // Fallback: just send the selected codes as true
    return selectedCodes.map((code) {
      return {
        'code': code,
        'value': true,
      };
    }).toList();
  }

  factory ProfileUpdateRequest.fromAuthState(
    AuthState s, {
    List<PhysiologicalCategory> availableCategories = const [],
  }) {
    int? computedAge;
    if (s.dateOfBirth != null) {
      final now = DateTime.now();
      int years = now.year - s.dateOfBirth!.year;
      final hasHadBirthdayThisYear = (now.month > s.dateOfBirth!.month) ||
          (now.month == s.dateOfBirth!.month && now.day >= s.dateOfBirth!.day);
      if (!hasHadBirthdayThisYear) years -= 1;
      computedAge = max(0, years);
    }

    // Build specialConditions as array format
    final specialConditionsArray = _buildSpecialConditionsArray(
      s.selectedConditionCodes,
      availableCategories,
    );

    // Map regularityStatus to digestiveIssues
    final digestive = _mapRegularityStatusToDigestiveIssues(s.regularityStatus);

    final addr = Address(
      buildingName: s.buildingNameNumber.isNotEmpty ? s.buildingNameNumber : null,
      street: s.street.isNotEmpty ? s.street : null,
      pincode: s.pincode.isNotEmpty ? s.pincode : null,
      latitude: s.latitude,
      longitude: s.longitude,
    );

    return ProfileUpdateRequest(
      name: s.name.isNotEmpty ? s.name : null,
      email: '',
      age: computedAge,
      gender: s.gender.isNotEmpty ? s.gender : null,
      weight: s.weight,
      height: s.height,
      selectedGoal: s.selectedGoal.isNotEmpty ? s.selectedGoal : "regular-bmi-maintenance",
      doesWorkout: s.doesExercise,
      workoutDaysPerWeek: s.exerciseDaysPerWeek,
      workoutHoursPerDay: s.exerciseDurationHours,
      exerciseType: s.exerciseType,
      profession: s.physicalActivityLevel.isNotEmpty ? s.physicalActivityLevel : null,
      address: addr,
      specialConditions: specialConditionsArray,
      digestiveIssues: digestive,
      selectedKitchenId: '',
      imgUrl: s.imgUrl != null && s.imgUrl!.isNotEmpty ? s.imgUrl : null,
    );
  }

  Map<String, dynamic> toJson() => toFullJson();

  /// Always include all fields as backend expects full object.
  Map<String, dynamic> toFullJson() {
    final map = {
      'name': name ?? '',
      'imgUrl': imgUrl ?? '',
      'age': age ?? 0,
      'height': height ?? 0,
      'weight': weight ?? 0,
      'doesWorkout': doesWorkout ?? false,
      'gender': gender ?? '',
      'address': (address ?? const Address()).toFullJson(),
      'selectedKitchenId': selectedKitchenId ?? '',
      'selectedGoal': selectedGoal ?? '',
      'profession': profession ?? 'type-1',
      'workoutDaysPerWeek': workoutDaysPerWeek ?? 0,
      'workoutHoursPerDay': workoutHoursPerDay ?? 0,
      'exerciseType': exerciseType ?? '',
      'specialConditions': specialConditions ?? [],
      'digestiveIssues': (digestiveIssues ?? const DigestiveIssues(
        regularlyConstipated: false,
        diarrhoeal: false,
        none: false,
        both: false,
      )).toFullJson(),
      'isUpdateable': isUpdateable,
    };
    // Only include email if it's not empty to avoid backend validation error
    if (email != null && email!.isNotEmpty) {
      map['email'] = email!;
    }
    return map;
  }
}

class Address {
  final String? buildingName;
  final String? street;
  final String? pincode;
  final double? latitude;
  final double? longitude;

  const Address({
    this.buildingName,
    this.street,
    this.pincode,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => toFullJson();

  Map<String, dynamic> toFullJson() {
    return {
      'buildingName': buildingName ?? '',
      'street': street ?? '',
      'pincode': pincode ?? '',
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
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
