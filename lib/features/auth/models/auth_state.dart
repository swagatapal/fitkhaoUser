class AuthState {
  final String? userId;
  final String phoneNumber;
  final String countryCode;
  final bool isTermsAccepted;
  final bool isLoading;
  final String? errorMessage;
  final String otp;
  final String? otpId;
  final bool isResendingOtp;
  final int resendTimer;
  final bool canResend;
  final String? receivedOtpMessage;
  final String? imgUrl;

  // User profile data
  final String name;
  final String gender;
  final DateTime? dateOfBirth;
  final double? height;
  final double? weight;
  final double? age;

  // Address data
  final String buildingNameNumber;
  final String street;
  final String pincode;
  final double? latitude;
  final double? longitude;

  // BMI and health data
  final double? bmi;
  final int? healthScore;
  final bool doesExercise;

  // Detailed health information
  final String physicalActivityLevel;
  final int? exerciseDaysPerWeek;
  final double? exerciseDurationHours;
  final String exerciseType;
  final bool pregnancy;
  final String? pregnancyStage; // P1, P2, P3
  final bool lactation;
  final String? lactationStage; // L1, L2
  final bool diabetes;
  final bool hypertension;
  final bool cardiacProblem;
  final bool kidneyDisease;
  final bool liverRelatedProblem;
  final String otherConditions;
  final String regularityStatus;

  // Nutritional targets
  final double? targetProtein;
  final double? targetFat;
  final double? targetCarbs;
  final double? targetKCalories;
  final DateTime? lastUpdatedTargetKCal;
  final String selectedGoal;
  final String profession;

  // Profile update tracking
  final DateTime? profileUpdatedAt;

  const AuthState({
    this.userId,
    this.phoneNumber = '',
    this.countryCode = '+91',
    this.isTermsAccepted = false,
    this.isLoading = false,
    this.errorMessage,
    this.age,
    this.otp = '',
    this.otpId,
    this.imgUrl,
    this.isResendingOtp = false,
    this.resendTimer = 0,
    this.canResend = false,
    this.receivedOtpMessage,
    this.name = '',
    this.gender = 'female',
    this.dateOfBirth,
    this.height,
    this.weight,
    this.buildingNameNumber = '',
    this.street = '',
    this.pincode = '',
    this.latitude,
    this.longitude,
    this.bmi,
    this.healthScore,
    this.doesExercise = false,
    this.physicalActivityLevel = '',
    this.exerciseDaysPerWeek,
    this.exerciseDurationHours,
    this.exerciseType = 'type-1',
    this.pregnancy = false,
    this.pregnancyStage,
    this.lactation = false,
    this.lactationStage,
    this.diabetes = false,
    this.hypertension = false,
    this.cardiacProblem = false,
    this.kidneyDisease = false,
    this.liverRelatedProblem = false,
    this.otherConditions = '',
    this.regularityStatus = 'None',
    this.targetProtein,
    this.targetFat,
    this.targetCarbs,
    this.targetKCalories,
    this.lastUpdatedTargetKCal,
    this.selectedGoal = 'regular-bmi-maintenance',
    this.profession = "type-1",
    this.profileUpdatedAt,
  });

  AuthState copyWith({
    String? userId,
    String? phoneNumber,
    String? countryCode,
    bool? isTermsAccepted,
    bool? isLoading,
    String? errorMessage,
    String? otp,
    String? otpId,
    String? imgUrl,
    double? age,
    bool? isResendingOtp,
    int? resendTimer,
    bool? canResend,
    String? receivedOtpMessage,
    String? name,
    String? gender,
    DateTime? dateOfBirth,
    double? height,
    double? weight,
    String? buildingNameNumber,
    String? street,
    String? pincode,
    double? latitude,
    double? longitude,
    double? bmi,
    int? healthScore,
    bool? doesExercise,
    String? physicalActivityLevel,
    int? exerciseDaysPerWeek,
    double? exerciseDurationHours,
    String? exerciseType,
    bool? pregnancy,
    String? pregnancyStage,
    bool? lactation,
    String? lactationStage,
    bool? diabetes,
    bool? hypertension,
    bool? cardiacProblem,
    bool? kidneyDisease,
    bool? liverRelatedProblem,
    String? otherConditions,
    String? regularityStatus,
    double? targetProtein,
    double? targetFat,
    double? targetCarbs,
    double? targetKCalories,
    DateTime? lastUpdatedTargetKCal,
    String? selectedGoal,
    String? profession,
    DateTime? profileUpdatedAt,
  }) {
    return AuthState(
      userId: userId?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      isTermsAccepted: isTermsAccepted ?? this.isTermsAccepted,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      otp: otp ?? this.otp,
      otpId: otpId ?? this.otpId,
      isResendingOtp: isResendingOtp ?? this.isResendingOtp,
      resendTimer: resendTimer ?? this.resendTimer,
      canResend: canResend ?? this.canResend,
      receivedOtpMessage: receivedOtpMessage ?? this.receivedOtpMessage,
      name: name ?? this.name,
      imgUrl: imgUrl ?? this.imgUrl,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      height: height ?? this.height,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      buildingNameNumber: buildingNameNumber ?? this.buildingNameNumber,
      street: street ?? this.street,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      bmi: bmi ?? this.bmi,
      healthScore: healthScore ?? this.healthScore,
      doesExercise: doesExercise ?? this.doesExercise,
      physicalActivityLevel: physicalActivityLevel ?? this.physicalActivityLevel,
      exerciseDaysPerWeek: exerciseDaysPerWeek ?? this.exerciseDaysPerWeek,
      exerciseDurationHours: exerciseDurationHours ?? this.exerciseDurationHours,
      exerciseType: exerciseType ?? this.exerciseType,
      pregnancy: pregnancy ?? this.pregnancy,
      pregnancyStage: pregnancyStage ?? this.pregnancyStage,
      lactation: lactation ?? this.lactation,
      lactationStage: lactationStage ?? this.lactationStage,
      diabetes: diabetes ?? this.diabetes,
      hypertension: hypertension ?? this.hypertension,
      cardiacProblem: cardiacProblem ?? this.cardiacProblem,
      kidneyDisease: kidneyDisease ?? this.kidneyDisease,
      liverRelatedProblem: liverRelatedProblem ?? this.liverRelatedProblem,
      otherConditions: otherConditions ?? this.otherConditions,
      regularityStatus: regularityStatus ?? this.regularityStatus,
      targetProtein: targetProtein ?? this.targetProtein,
      targetFat: targetFat ?? this.targetFat,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetKCalories: targetKCalories ?? this.targetKCalories,
      lastUpdatedTargetKCal: lastUpdatedTargetKCal ?? this.lastUpdatedTargetKCal,
      selectedGoal: selectedGoal ?? this.selectedGoal,
      profession: profession??this.profession,
      profileUpdatedAt: lastUpdatedTargetKCal ?? this.lastUpdatedTargetKCal,
    );
  }
}
