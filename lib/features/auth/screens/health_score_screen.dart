import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../shared/widgets/logo_widget.dart';
import '../../../shared/widgets/primary_button.dart';
import '../models/auth_state.dart';
import '../models/profile_update_model.dart';
import '../providers/auth_provider.dart';

class HealthScoreScreen extends ConsumerStatefulWidget {
  final int healthScore;
  final String scoreLevel;

  const HealthScoreScreen({
    super.key,
    required this.healthScore,
    required this.scoreLevel,
  });

  @override
  ConsumerState<HealthScoreScreen> createState() => _HealthScoreScreenState();
}

class _HealthScoreScreenState extends ConsumerState<HealthScoreScreen> {
  Future<void> _handleStartExploring() async {
    final authNotifier = ref.read(authProvider.notifier);
    final authState = ref.read(authProvider);

    // Print all collected data before API call
    debugPrint('========================================');
    debugPrint('PROFILE DATA COLLECTED:');
    debugPrint('========================================');
    debugPrint('Phone Number: ${authState.phoneNumber}');
    debugPrint('Name: ${authState.name}');
    debugPrint('Gender: ${authState.gender}');
    debugPrint('Date of Birth: ${authState.dateOfBirth}');
    debugPrint('Height: ${authState.height} cm');
    debugPrint('Weight: ${authState.weight} kg');
    debugPrint('Does Exercise: ${authState.doesExercise}');
    debugPrint('Exercise Days/Week: ${authState.exerciseDaysPerWeek}');
    debugPrint('Exercise Hours/Day: ${authState.exerciseDurationHours}');
    debugPrint('Exercise Type: ${authState.exerciseType}');
    debugPrint('Physical Activity Level: ${authState.physicalActivityLevel}');
    debugPrint('BMI: ${authState.bmi}');
    debugPrint('Health Score: ${authState.healthScore}');
    debugPrint('========================================');
    debugPrint('ADDRESS:');
    debugPrint('Building: ${authState.buildingNameNumber}');
    debugPrint('Street: ${authState.street}');
    debugPrint('Pincode: ${authState.pincode}');
    debugPrint('Latitude: ${authState.latitude}');
    debugPrint('Longitude: ${authState.longitude}');
    debugPrint('========================================');
    debugPrint('HEALTH CONDITIONS:');
    debugPrint('Diabetes: ${authState.diabetes}');
    debugPrint('Hypertension: ${authState.hypertension}');
    debugPrint('Cardiac Problem: ${authState.cardiacProblem}');
    debugPrint('Kidney Disease: ${authState.kidneyDisease}');
    debugPrint('Liver Problem: ${authState.liverRelatedProblem}');
    debugPrint('Pregnancy: ${authState.pregnancy}');
    debugPrint('Lactation: ${authState.lactation}');
    debugPrint('Other Conditions: ${authState.otherConditions}');
    debugPrint('Regularity Status: ${authState.regularityStatus}');
    debugPrint('========================================');

    // Generate profile update model to see what will be sent to API
    final profileData = ProfileUpdateRequest.fromAuthState(authState);
    debugPrint('API PAYLOAD:');
    debugPrint('${profileData.toFullJson()}');
    debugPrint('========================================');

    // Complete registration
    final success = await authNotifier.completeRegistration();

    if (success && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration completed successfully!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate to home screen
      context.go(RouteNames.home);
    }
    // Error message will be shown via listener
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for errors
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
    // Get responsive values
    final horizontalPadding = context.horizontalPadding;
    final spacing12 = context.responsiveSpacing(12.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing20 = context.responsiveSpacing(20.0);
    final spacing24 = context.responsiveSpacing(24.0);
    final spacing48 = context.responsiveSpacing(48.0);

    // Determine gradient colors based on score level
    List<Color> gradientColors = _getGradientColors(widget.scoreLevel);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: spacing24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              const Center(child: LogoWidget()),
              SizedBox(height: spacing16),

              // Title
              Text(
                AppStrings.yourHealthScore,
                style: TextStyle(
                  fontSize: context.responsiveFontSize(22.0),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              SizedBox(height: spacing12),

              // Score Level
              Text(
                widget.scoreLevel,
                style: TextStyle(
                  fontSize: context.responsiveFontSize(18.0),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              SizedBox(height: spacing24),

              // Score Card with Gradient
              Center(
                child: Container(
                  width: AppSizes.scoreCardWidth,
                  height: AppSizes.scoreCardHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(
                      context.responsiveSpacing(8.0),
                    ),
                  ),
                  child: Stack(
                    children: [
                      widget.scoreLevel == "low"
                          ? Image.asset(
                              "assets/images/red.png",
                              fit: BoxFit.cover,
                              width: AppSizes.scoreCardWidth,
                              height: AppSizes.scoreCardHeight,
                            )
                          : widget.scoreLevel == "good"
                          ? Image.asset(
                              "assets/images/green.png",
                              fit: BoxFit.cover,
                              width: AppSizes.scoreCardWidth,
                              height: AppSizes.scoreCardHeight,
                            )
                          : Image.asset(
                              "assets/images/yellow.png",
                              fit: BoxFit.cover,
                              width: AppSizes.scoreCardWidth,
                              height: AppSizes.scoreCardHeight,
                            ),
                      Center(
                        child: Text(
                          '${widget.healthScore}/100',
                          style: TextStyle(
                            fontSize: context.responsiveFontSize(32.0),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing48),

              // Info Card
              Container(
                padding: EdgeInsets.all(spacing12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    context.responsiveSpacing(4.0),
                  ),
                  //border: Border.all(color: AppColors.borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Color(
                        0xFF18181B,
                      ).withOpacity(0.10), 
                      offset: Offset(0, 16), 
                      blurRadius: 24, 
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Color(
                        0xFF18181B,
                      ).withOpacity(0.30), 
                      offset: Offset(0, 0), 
                      blurRadius: 1, 
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: AppSizes.iconContainerSize,
                      height: AppSizes.iconContainerSize,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lightbulb_sharp,
                        color: Colors.white,
                        size: AppSizes.icon28,
                      ),
                    ),
                    SizedBox(width: spacing16),
                    Expanded(
                      child: Text(
                        AppStrings.healthScoreInfo,
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(15.0),
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                          height: 1.4,
                          fontWeight: FontWeight.w400
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing48),

              // Start Exploring Button (Outlined)
              PrimaryButton(
                text: AppStrings.startExploring,
                onPressed: !authState.isLoading ? _handleStartExploring : null,
                textColor: AppColors.primaryGreen,
                height: context.inputHeight,
                isLoading: authState.isLoading,
                backgroundColor: Colors.white,
                borderColor: AppColors.primaryGreen,
                borderWidth: AppSizes.borderMedium,
              ),
              SizedBox(height: spacing16),

              // Add Information Button (Filled)
              // PrimaryButton(
              //   text: AppStrings.addYourInformation,
              //   onPressed: () {
              //     // Navigate to detailed health information screen
              //     context.push(RouteNames.detailedHealthInfo);
              //   },
              //   textColor: Colors.white,
              //   height: context.inputHeight,
              //   isLoading: false,
              // ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        // Red to Orange gradient
        return [
          const Color(0xFFE74C3C), // Red
          const Color(0xFFE67E22), // Orange
        ];
      case 'medium':
        // Yellow to Gold gradient
        return [
          const Color(0xFFF39C12), // Gold/Yellow
          const Color(0xFFF1C40F), // Yellow
        ];
      case 'good':
        // Green gradient
        return [
          const Color(0xFF27AE60), // Green
          const Color(0xFF2ECC71), // Light Green
        ];
      default:
        return [AppColors.primaryGreen, AppColors.primaryGreen];
    }
  }
}
