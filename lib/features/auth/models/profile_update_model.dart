import 'dart:math';

import '../../profile/models/physiological_category_model.dart';
import 'auth_state.dart';

class ProfileUpdateRequest {
  final String? name;
  final String? email;
  final num? age; // years — may be fractional (e.g. 12.5)
  final String? gender; // male|female
  final double? weight; // kg
  final double? height; // cm
  final String? selectedGoal;
  final bool? doesWorkout;

  /// MongoDB _id of the selected ProfessionGroup
  final String? professionGroupId;

  /// Per-exercise data: [{exerciseGroupId, daysPerWeek, hoursPerDay}]
  final List<Map<String, dynamic>>? exercises;
  final Address? address;
  final List<Map<String, dynamic>>? specialConditions;
  final DigestiveIssues? digestiveIssues;
  final String? selectedKitchenId;
  final String? imgUrl;
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
    this.professionGroupId,
    this.exercises,
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

    if (lower.contains('both') ||
        (lower.contains('constipat') && lower.contains('diarrh'))) {
      return const DigestiveIssues(
        regularlyConstipated: true,
        regularlyDiarrhoeal: true,
        none: false,
        both: true,
      );
    } else if (lower.contains('constipat')) {
      return const DigestiveIssues(
        regularlyConstipated: true,
        regularlyDiarrhoeal: false,
        none: false,
        both: false,
      );
    } else if (lower.contains('diarrh')) {
      return const DigestiveIssues(
        regularlyConstipated: false,
        regularlyDiarrhoeal: true,
        none: false,
        both: false,
      );
    }

    return const DigestiveIssues(
      regularlyConstipated: false,
      regularlyDiarrhoeal: false,
      none: true,
      both: false,
    );
  }

  /// Build specialConditions array from selected codes and available categories
  static List<Map<String, dynamic>> _buildSpecialConditionsArray(
    List<String> selectedCodes,
    List<PhysiologicalCategory> availableCategories,
  ) {
    if (availableCategories.isNotEmpty) {
      return availableCategories.map((cat) {
        return {
          'code': cat.code,
          'value': selectedCodes.contains(cat.code),
        };
      }).toList();
    }

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

    final specialConditionsArray = _buildSpecialConditionsArray(
      s.selectedConditionCodes,
      availableCategories,
    );

    final digestive = _mapRegularityStatusToDigestiveIssues(s.regularityStatus);

    final addr = Address(
      buildingName:
          s.buildingNameNumber.isNotEmpty ? s.buildingNameNumber : null,
      street: s.street.isNotEmpty ? s.street : null,
      pincode: s.pincode.isNotEmpty ? s.pincode : null,
      latitude: s.latitude,
      longitude: s.longitude,
    );

    return ProfileUpdateRequest(
      name: s.name.isNotEmpty ? s.name : null,
      email: '',
      // Prefer the entered age (keeps decimals like 12.5); fall back to the
      // age derived from date of birth.
      age: s.age ?? computedAge,
      gender: s.gender.isNotEmpty ? s.gender : null,
      weight: s.weight,
      height: s.height,
      selectedGoal: s.selectedGoal.isNotEmpty
          ? s.selectedGoal
          : 'regular-bmi-maintenance',
      doesWorkout: s.doesExercise,
      professionGroupId:
          s.professionGroupId.isNotEmpty ? s.professionGroupId : null,
      exercises: s.exercises.isNotEmpty ? s.exercises : null,
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
    final map = <String, dynamic>{
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
      'professionGroupId': professionGroupId ?? '',
      'exercises': exercises ?? [],
      'specialConditions': specialConditions ?? [],
      'digestiveIssues': (digestiveIssues ??
              const DigestiveIssues(
                regularlyConstipated: false,
                regularlyDiarrhoeal: false,
                none: false,
                both: false,
              ))
          .toFullJson(),
      'isUpdateable': isUpdateable,
    };
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
  final bool regularlyDiarrhoeal;
  final bool none;
  final bool both;

  const DigestiveIssues({
    required this.regularlyConstipated,
    required this.regularlyDiarrhoeal,
    required this.none,
    required this.both,
  });

  Map<String, dynamic> toJson() => toFullJson();

  Map<String, dynamic> toFullJson() {
    return {
      'regularlyConstipated': regularlyConstipated,
      'regularlyDiarrhoeal': regularlyDiarrhoeal,
      'none': none,
      'both': both,
    };
  }
}
