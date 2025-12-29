import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/models/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';

class DetailedHealthInfoScreen extends ConsumerStatefulWidget {
  const DetailedHealthInfoScreen({super.key});

  @override
  ConsumerState<DetailedHealthInfoScreen> createState() =>
      _DetailedHealthInfoScreenState();
}

class _DetailedHealthInfoScreenState
    extends ConsumerState<DetailedHealthInfoScreen> {
  // Form fields
  String _age = '';
  String _heightCm = '';
  String _weightKg = '';
  String _activityLevel = 'sedentary'; // sedentary, moderate, heavy
  bool _doesExercise = true;
  String _exerciseDaysPerWeek = '';
  String _exerciseDurationHrs = '';
  String _exerciseType = 'aerobic'; // aerobic, strength, flexibility

  // Physiological conditions
  final Set<String> _conditions = {};
  String _otherConditions = '';

  String _regularlyStatus =
      'constipated'; // constipated, diarrhoeal, both, none

  // Goal selection
  String _selectedGoal = 'fat-loss'; // fat-loss, lean-mass-gain, regular-bmi-maintenance

  // Pregnancy and Lactation stages
  String _pregnancyStage = 'P1'; // P1, P2, P3
  String _lactationStage = 'L1'; // L1, L2

  // Controllers
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _otherConditionsController =
      TextEditingController();

  bool _isInitialized = false;
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    // Load profile data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _daysController.dispose();
    _durationController.dispose();
    _otherConditionsController.dispose();
    super.dispose();
  }

  /// Load profile data from API
  Future<void> _loadProfileData() async {
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.loadProfile();

    if (success && mounted) {
      _populateFormFields();
    }
  }

  /// Populate form fields with data from AuthState
  void _populateFormFields() {
    final authState = ref.read(authProvider);

    setState(() {
      // Basic info
      // Load existing profile image URL from server
      if (authState.imgUrl != null && authState.imgUrl!.isNotEmpty) {
        _uploadedImageUrl = authState.imgUrl;
      }

      if (authState.age != null && authState.age! > 0) {
        _age = authState.age!.toStringAsFixed(0);
        _ageController.text = _age;
      }
      if (authState.height != null && authState.height! > 0) {
        _heightCm = authState.height!.toStringAsFixed(0);
        _heightController.text = _heightCm;
      }
      if (authState.weight != null && authState.weight! > 0) {
        _weightKg = authState.weight!.toStringAsFixed(0);
        _weightController.text = _weightKg;
      }

      // Activity level - map from API format (type-1, type-2, type-3) to UI format
      _activityLevel = _mapProfessionFromApi(authState.physicalActivityLevel);

      // Exercise info
      _doesExercise = authState.doesExercise;
      if (authState.exerciseDaysPerWeek != null &&
          authState.exerciseDaysPerWeek! > 0) {
        _exerciseDaysPerWeek = authState.exerciseDaysPerWeek!.toString();
        _daysController.text = _exerciseDaysPerWeek;
      }
      if (authState.exerciseDurationHours != null &&
          authState.exerciseDurationHours! > 0) {
        _exerciseDurationHrs = authState.exerciseDurationHours!.toStringAsFixed(
          0,
        );
        _durationController.text = _exerciseDurationHrs;
      }

      // Exercise type - map from API format (type-1, type-2, type-3) to UI format
      _exerciseType = _mapExerciseTypeFromApi(authState.exerciseType);

      // Health conditions
      _conditions.clear();
      if (authState.pregnancy) _conditions.add('pregnancy');
      if (authState.lactation) _conditions.add('lactation');
      if (authState.diabetes) _conditions.add('diabetes');
      if (authState.hypertension) _conditions.add('hypertension');
      if (authState.cardiacProblem) _conditions.add('cardiac');
      if (authState.kidneyDisease) _conditions.add('kidney');
      if (authState.liverRelatedProblem) _conditions.add('liver');
      if (authState.otherConditions.isNotEmpty) {
        _conditions.add('others');
        _otherConditions = authState.otherConditions;
        _otherConditionsController.text = _otherConditions;
      }

      // Regularity status
      _regularlyStatus = authState.regularityStatus.toLowerCase();

      // Selected goal
      if (authState.selectedGoal.isNotEmpty) {
        _selectedGoal = authState.selectedGoal;
      }

      // Pregnancy and Lactation stages
      if (authState.pregnancyStage != null && authState.pregnancyStage!.isNotEmpty) {
        _pregnancyStage = authState.pregnancyStage!;
      }
      if (authState.lactationStage != null && authState.lactationStage!.isNotEmpty) {
        _lactationStage = authState.lactationStage!;
      }

      _isInitialized = true;
    });
  }

  /// Map profession from API format to UI format
  /// type-1 → sedentary, type-2 → moderate, type-3 → heavy
  String _mapProfessionFromApi(String apiValue) {
    switch (apiValue.toLowerCase()) {
      case 'type-1':
        return 'sedentary';
      case 'type-2':
        return 'moderate';
      case 'type-3':
        return 'heavy';
      default:
        // If it's already in UI format or unknown, check if it matches UI values
        if (apiValue.toLowerCase() == 'sedentary' ||
            apiValue.toLowerCase() == 'moderate' ||
            apiValue.toLowerCase() == 'heavy') {
          return apiValue.toLowerCase();
        }
        return 'sedentary'; // default
    }
  }

  /// Map profession from UI format to API format
  /// sedentary → type-1, moderate → type-2, heavy → type-3
  String _mapProfessionToApi(String uiValue) {
    switch (uiValue.toLowerCase()) {
      case 'sedentary':
        return 'type-1';
      case 'moderate':
        return 'type-2';
      case 'heavy':
        return 'type-3';
      default:
        return 'type-1'; // default
    }
  }

  /// Map exercise type from API format to UI format
  /// type-1 → aerobic, type-2 → strength, type-3 → flexibility
  String _mapExerciseTypeFromApi(String apiValue) {
    switch (apiValue.toLowerCase()) {
      case 'type-1':
        return 'aerobic';
      case 'type-2':
        return 'strength';
      case 'type-3':
        return 'flexibility';
      default:
        // If it's already in UI format or unknown
        if (apiValue.toLowerCase() == 'aerobic' ||
            apiValue.toLowerCase() == 'strength' ||
            apiValue.toLowerCase() == 'flexibility') {
          return apiValue.toLowerCase();
        }
        return 'aerobic'; // default
    }
  }

  /// Map exercise type from UI format to API format
  /// aerobic → type-1, strength → type-2, flexibility → type-3
  String _mapExerciseTypeToApi(String uiValue) {
    switch (uiValue.toLowerCase()) {
      case 'aerobic':
        return 'type-1';
      case 'strength':
        return 'type-2';
      case 'flexibility':
        return 'type-3';
      default:
        return 'type-1'; // default
    }
  }

  bool get _isFormValid {
    // Allow saving with any combination of fields
    return true;
  }

  Future<void> _handleSave() async {
    final authNotifier = ref.read(authProvider.notifier);
    final authState = ref.read(authProvider);

    // Parse optional numeric fields
    final parsedAge = _age.isNotEmpty ? double.tryParse(_age) : null;
    final parsedHeight = _heightCm.isNotEmpty ? double.tryParse(_heightCm) : null;
    final parsedWeight = _weightKg.isNotEmpty ? double.tryParse(_weightKg) : null;
    final parsedExerciseDays = _exerciseDaysPerWeek.isNotEmpty ? int.tryParse(_exerciseDaysPerWeek) : null;
    final parsedExerciseDuration = _exerciseDurationHrs.isNotEmpty ? double.tryParse(_exerciseDurationHrs) : null;

    // Calculate dateOfBirth from age if age is provided
    DateTime? dateOfBirth;
    if (parsedAge != null && parsedAge > 0) {
      final now = DateTime.now();
      final ageInt = parsedAge.toInt();
      dateOfBirth = DateTime(now.year - ageInt, now.month, now.day);
    }

    // Save personal info only if we have values
    if (parsedAge != null || parsedHeight != null || parsedWeight != null || dateOfBirth != null) {
      authNotifier.savePersonalInfo(
        gender: authState.gender.isNotEmpty ? authState.gender : 'male',
        dateOfBirth: dateOfBirth ?? authState.dateOfBirth ?? DateTime.now(),
        height: parsedHeight ?? authState.height ?? 0.0,
        weight: parsedWeight ?? authState.weight ?? 0.0,
        age: parsedAge ?? authState.age ?? 0.0,
        doesExercise: _doesExercise,
      );
    }

    // Map UI values to API format before saving
    final professionApiFormat = _mapProfessionToApi(_activityLevel);
    final exerciseTypeApiFormat = _mapExerciseTypeToApi(_exerciseType);

    // Save detailed health information to provider with API format
    authNotifier.saveDetailedHealthInfo(
      height: parsedHeight ?? authState.height ?? 0,
      weight: parsedWeight ?? authState.weight ?? 0,
      age: parsedAge ?? authState.age ?? 0,
      physicalActivityLevel: professionApiFormat,
      // Use API format (type-1, type-2, type-3)
      doesExercise: _doesExercise,
      exerciseDaysPerWeek: _doesExercise && parsedExerciseDays != null
          ? parsedExerciseDays
          : null,
      exerciseDurationHours: _doesExercise && parsedExerciseDuration != null
          ? parsedExerciseDuration
          : null,
      exerciseType: exerciseTypeApiFormat,
      // Use API format (type-1, type-2, type-3)
      pregnancy: _conditions.contains('pregnancy'),
      pregnancyStage: _conditions.contains('pregnancy') ? _pregnancyStage : null,
      lactation: _conditions.contains('lactation'),
      lactationStage: _conditions.contains('lactation') ? _lactationStage : null,
      diabetes: _conditions.contains('diabetes'),
      hypertension: _conditions.contains('hypertension'),
      cardiacProblem: _conditions.contains('cardiac'),
      kidneyDisease: _conditions.contains('kidney'),
      liverRelatedProblem: _conditions.contains('liver'),
      otherConditions: _conditions.contains('others') ? _otherConditions : '',
      regularityStatus: _capitalize(_regularlyStatus),
      selectedGoal: _selectedGoal,
    );

    // Complete registration with collected data (calls PUT API)
    final success = await authNotifier.completeRegistration();

    if (success && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate to preferences saved screen
      context.go(RouteNames.preferencesSaved);
    }
    // Error message will be shown via listener
  }

  // Extension helper for capitalizing strings
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
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

    final spacing12 = context.responsiveSpacing(12.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing20 = context.responsiveSpacing(20.0);
    final spacing24 = context.responsiveSpacing(24.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main Column with Fixed Image and Scrollable Content
          Column(
            children: [
              // Fixed Image Section at Top
              _buildImageSection(),

              //  SizedBox(height: 20,),
              // Scrollable Content Below Image
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(spacing20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Select type of Physical Activity",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF2B292A),
                          fontFamily: "Lato",
                        ),
                      ),
                      SizedBox(height: spacing12),

                      // Body Details Section
                      _buildSectionTitle(AppStrings.bodyDetails),
                      SizedBox(height: spacing12),
                      _buildNumberField(
                        label: AppStrings.ageDetails,
                        controller: _ageController,
                        onChanged: (value) => setState(() => _age = value),
                      ),
                      SizedBox(height: spacing12),
                      _buildNumberField(
                        label: AppStrings.heightInCms,
                        controller: _heightController,
                        onChanged: (value) => setState(() => _heightCm = value),
                      ),
                      SizedBox(height: spacing12),
                      _buildNumberField(
                        label: AppStrings.weightInKg,
                        controller: _weightController,
                        onChanged: (value) => setState(() => _weightKg = value),
                      ),
                      SizedBox(height: spacing16),

                      // Goal Selection Section
                      Row(
                        children: [
                          const Text(
                            "Select Goal",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF2B292A),
                              fontFamily: "Lato",
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            "*",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: Colors.red,
                              fontFamily: "Lato",
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGoalOption(
                              title: 'Fat Loss',
                              value: 'fat-loss',
                            ),
                          ),
                          SizedBox(width: spacing12),
                          Expanded(
                            child: _buildGoalOption(
                              title: 'Lean Mass Gain',
                              value: 'lean-mass-gain',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing12),
                      _buildGoalOption(
                        title: 'Regular BMI Maintenance',
                        value: 'regular-bmi-maintenance',
                      ),
                      SizedBox(height: spacing16),

                      // Physical Activity Section
                      _buildSectionTitle(AppStrings.professionPhysicalWork),
                      SizedBox(height: spacing16),
                      _buildActivityOption(
                        title: AppStrings.sedentary,
                        description: AppStrings.sedentaryDesc,
                        value: 'sedentary',
                      ),
                      SizedBox(height: spacing12),
                      _buildActivityOption(
                        title: AppStrings.moderate,
                        description: AppStrings.moderateDesc,
                        value: 'moderate',
                      ),
                      SizedBox(height: spacing12),
                      _buildActivityOption(
                        title: AppStrings.heavy,
                        description: AppStrings.heavyDesc,
                        value: 'heavy',
                      ),
                      SizedBox(height: spacing16),

                      // Exercise Section
                      _buildSectionTitle(AppStrings.exercise),
                      SizedBox(height: spacing16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildExerciseToggle(
                              label: AppStrings.iExercise,
                              icon: Icons.fitness_center,
                              isSelected: _doesExercise,
                              onTap: () => setState(() => _doesExercise = true),
                            ),
                          ),
                          SizedBox(width: spacing12),
                          Expanded(
                            child: _buildExerciseToggle(
                              label: AppStrings.iDontExerciseShort,
                              icon: Icons.event_busy,
                              isSelected: !_doesExercise,
                              onTap: () =>
                                  setState(() => _doesExercise = false),
                            ),
                          ),
                        ],
                      ),

                      // Exercise Details (shown only if exercises)
                      if (_doesExercise) ...[
                        SizedBox(height: spacing16),
                        _buildNumberField(
                          label: AppStrings.howManyDaysWeek,
                          controller: _daysController,
                          onChanged: (value) =>
                              setState(() => _exerciseDaysPerWeek = value),
                          maxValue: 7,
                        ),
                        SizedBox(height: spacing12),
                        _buildNumberField(
                          label: AppStrings.durationInHrs,
                          controller: _durationController,
                          onChanged: (value) =>
                              setState(() => _exerciseDurationHrs = value),
                          maxValue: 24,
                        ),
                        SizedBox(height: spacing16),
                        _buildSectionTitle(AppStrings.typeOfExercise),
                        SizedBox(height: spacing12),
                        _buildExerciseTypeOption(
                          title: AppStrings.aerobic,
                          description: AppStrings.aerobicDesc,
                          value: 'aerobic',
                          icon: Icons.directions_run,
                        ),
                        SizedBox(height: spacing12),
                        _buildExerciseTypeOption(
                          title: AppStrings.strengthTraining,
                          description: AppStrings.strengthTrainingDesc,
                          value: 'strength',
                          icon: Icons.fitness_center,
                        ),
                        SizedBox(height: spacing12),
                        _buildExerciseTypeOption(
                          title: AppStrings.flexibilityExercise,
                          description: AppStrings.flexibilityExerciseDesc,
                          value: 'flexibility',
                          icon: Icons.self_improvement,
                        ),
                      ],

                      SizedBox(height: spacing20),

                      // Physiological Status Section
                      Text(
                        AppStrings.selectPhysiologicalStatus,
                        style: TextStyle(
                          fontFamily: "Lato",
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF2B292A),
                        ),
                      ),
                      SizedBox(height: spacing12),
                      Text(
                        AppStrings.physiologicalConditions,
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(14.0),
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      SizedBox(height: spacing12),
                      _buildCheckbox(AppStrings.pregnancy, 'pregnancy'),

                      // Pregnancy stages (shown only if pregnancy is checked)
                      if (_conditions.contains('pregnancy')) ...[
                        SizedBox(height: spacing12),
                        Padding(
                          padding: const EdgeInsets.only(left: 40.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPregnancyStageOption('P1 [1-3 months]', 'P1'),
                              SizedBox(height: spacing12),
                              _buildPregnancyStageOption('P2 [4-6 months]', 'P2'),
                              SizedBox(height: spacing12),
                              _buildPregnancyStageOption('P3 [7-9 months]', 'P3'),
                            ],
                          ),
                        ),
                      ],

                      _buildCheckbox(AppStrings.lactation, 'lactation'),

                      // Lactation stages (shown only if lactation is checked)
                      if (_conditions.contains('lactation')) ...[
                        SizedBox(height: spacing12),
                        Padding(
                          padding: const EdgeInsets.only(left: 40.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLactationStageOption('L1 [1-6 months]', 'L1'),
                              SizedBox(height: spacing12),
                              _buildLactationStageOption('L2 [6-12 months]', 'L2'),
                            ],
                          ),
                        ),
                      ],

                      _buildCheckbox(AppStrings.diabetes, 'diabetes'),
                      _buildCheckbox(AppStrings.hypertension, 'hypertension'),
                      _buildCheckbox(AppStrings.cardiacProblem, 'cardiac'),
                      _buildCheckbox(AppStrings.kidneyDisease, 'kidney'),
                      _buildCheckbox(AppStrings.liverRelatedProblem, 'liver'),
                      _buildCheckbox(AppStrings.others, 'others'),

                      if (_conditions.contains('others')) ...[
                        SizedBox(height: spacing12),
                        _buildTextField(
                          label: AppStrings.mentionOtherConditions,
                          controller: _otherConditionsController,
                          onChanged: (value) =>
                              setState(() => _otherConditions = value),
                          maxLines: 3,
                        ),
                      ],

                      SizedBox(height: spacing24),

                      // Regular Status Section
                      _buildSectionTitle(AppStrings.areYouRegularly),
                      SizedBox(height: spacing16),
                      _buildRegularStatusOption(
                        AppStrings.constipated,
                        'constipated',
                      ),
                      SizedBox(height: spacing12),
                      _buildRegularStatusOption(
                        AppStrings.diarrhoeal,
                        'diarrhoeal',
                      ),
                      SizedBox(height: spacing12),
                      _buildRegularStatusOption(AppStrings.both, 'both'),
                      SizedBox(height: spacing12),
                      _buildRegularStatusOption(AppStrings.none, 'none'),

                      SizedBox(height: spacing24),

                      // Save Button
                      PrimaryButton(
                        text: AppStrings.save,
                        onPressed: _isFormValid && !authState.isLoading
                            ? _handleSave
                            : null,
                        textColor: Colors.white,
                        height: context.inputHeight,
                        isLoading: authState.isLoading,
                      ),
                      SizedBox(height: context.responsiveSpacing(90.0)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Fixed Edit Button Overlay
          Positioned(
            top: 70,
            right: 30,
            child: GestureDetector(
              onTap: () => context.push(RouteNames.editPersonalProfile),
              child: Container(
                width: AppSizes.iconContainerSize,
                height: AppSizes.iconContainerSize,
                decoration: BoxDecoration(
                  color: Color(0xFF5D9E40),
                  borderRadius: BorderRadius.circular(AppSizes.radius15),
                ),
                child: Center(
                  child: Image.asset(
                    "assets/images/edit_user.png",
                    height: AppSizes.icon16,
                    width: AppSizes.icon19,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return SizedBox(
      width: double.infinity,
      height: 310,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Green gradient background with pattern
          Container(
            width: double.infinity,
            height: AppSizes.containerHeightLarge,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A7D33), Color(0xFF4A7D33)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Image.asset(
                "assets/images/header_bg.png",
                width: MediaQuery.of(context).size.width,
                height: AppSizes.containerHeightLarge,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Centered profile image
          Positioned(
            top: AppSizes.headerHeight,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: AppSizes.containerWidthLarge,
                height: AppSizes.containerHeightXLarge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radius16),
                  color: _uploadedImageUrl == null || _uploadedImageUrl!.isEmpty
                      ? AppColors.primaryGreen.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radius16),
                  child: _uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty
                      ? Image.network(
                          _uploadedImageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppColors.primaryGreen,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Image.network("https://i.sstatic.net/l60Hf.png", fit: BoxFit.cover,);
                          },
                        )
                      : Image.network("https://i.sstatic.net/l60Hf.png", fit: BoxFit.cover,)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: context.responsiveFontSize(14.0),
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        fontFamily: 'Lato',
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required Function(String) onChanged,
    int? maxValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.responsiveFontSize(14.0),
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            fontFamily: 'Lato',
          ),
        ),
        SizedBox(height: context.responsiveSpacing(8.0)),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: context.responsiveFontSize(14.0),
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontFamily: 'Lato',
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.responsiveSpacing(16.0),
              vertical: context.responsiveSpacing(12.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                context.responsiveSpacing(4.0),
              ),
              borderSide: const BorderSide(
                color: AppColors.borderColor,
                width: AppSizes.borderNormal,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                context.responsiveSpacing(4.0),
              ),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: AppSizes.borderMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required Function(String) onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.responsiveFontSize(13.0),
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        SizedBox(height: context.responsiveSpacing(8.0)),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: context.responsiveFontSize(14.0),
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
          decoration: InputDecoration(
            hintText: 'Text',
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontFamily: 'Lato',
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.responsiveSpacing(16.0),
              vertical: context.responsiveSpacing(12.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                context.responsiveSpacing(8.0),
              ),
              borderSide: const BorderSide(
                color: AppColors.borderColor,
                width: AppSizes.borderNormal,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                context.responsiveSpacing(8.0),
              ),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: AppSizes.borderMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityOption({
    required String title,
    required String description,
    required String value,
  }) {
    final isSelected = _activityLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _activityLevel = value),
      child: Container(
        padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(4.0)),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
            width: AppSizes.borderMedium,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
              size: AppSizes.icon20,
            ),
            SizedBox(width: context.responsiveSpacing(AppSizes.spacing12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: AppSizes.spacing10,
                    children: [
                      Image.asset(
                        "assets/images/user.png",
                        height: AppSizes.icon16,
                        width: AppSizes.icon16,
                      ),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(14.0),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.responsiveSpacing(4.0)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSizes.spacing10,
                    children: [
                      Image.asset(
                        "assets/images/tool.png",
                        height: AppSizes.icon16,
                        width: AppSizes.icon16,
                      ),
                      Expanded(
                        child: Text(
                          description,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: context.responsiveFontSize(12.0),
                            color: AppColors.textSecondary,
                            fontFamily: 'Lato',
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseToggle({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: context.responsiveSpacing(12.0),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(8.0)),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
            width: AppSizes.borderMedium,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.primaryGreen,
              size: AppSizes.icon18,
            ),
            SizedBox(width: context.responsiveSpacing(AppSizes.spacing6)),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: context.responsiveFontSize(12.0),
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
                maxLines: AppSizes.maxLines1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTypeOption({
    required String title,
    required String description,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _exerciseType == value;
    return GestureDetector(
      onTap: () => setState(() => _exerciseType = value),
      child: Container(
        padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(4.0)),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
            width: AppSizes.borderMedium,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
              size: AppSizes.icon20,
            ),
            SizedBox(width: context.responsiveSpacing(AppSizes.spacing12)),
            Icon(icon, color: AppColors.primaryGreen, size: AppSizes.icon20),
            SizedBox(width: context.responsiveSpacing(AppSizes.spacing8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(14.0),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  SizedBox(height: context.responsiveSpacing(4.0)),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(12.0),
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, String value) {
    final isChecked = _conditions.contains(value);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isChecked) {
            _conditions.remove(value);
          } else {
            _conditions.add(value);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.responsiveSpacing(8.0)),
        child: Row(
          children: [
            Container(
              width: AppSizes.checkboxSize,
              height: AppSizes.checkboxSize,
              decoration: BoxDecoration(
                color: isChecked ? AppColors.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radius4),
                border: Border.all(
                  color: isChecked
                      ? AppColors.primaryGreen
                      : AppColors.borderColor,
                  width: AppSizes.borderMedium,
                ),
              ),
              child: isChecked
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: AppSizes.icon14,
                    )
                  : null,
            ),
            SizedBox(width: context.responsiveSpacing(AppSizes.spacing12)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.responsiveFontSize(14.0),
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularStatusOption(String label, String value) {
    final isSelected = _regularlyStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _regularlyStatus = value),
      child: Container(
        padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(4.0)),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
            width: AppSizes.borderMedium,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
              size: AppSizes.icon20,
            ),
            SizedBox(width: context.responsiveSpacing(AppSizes.spacing12)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.responsiveFontSize(14.0),
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalOption({
    required String title,
    required String value,
  }) {
    final isSelected = _selectedGoal == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveSpacing(8.0),
          vertical: context.responsiveSpacing(8.0),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(50.0)),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: context.responsiveFontSize(14.0),
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildPregnancyStageOption(String label, String value) {
    final isSelected = _pregnancyStage == value;
    return GestureDetector(
      onTap: () => setState(() => _pregnancyStage = value),
      child: Container(
        padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(50.0)),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.white : AppColors.primaryGreen,
              size: AppSizes.icon20,
            ),
            SizedBox(width: context.responsiveSpacing(AppSizes.spacing12)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.responsiveFontSize(14.0),
                fontWeight: FontWeight.w400,
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLactationStageOption(String label, String value) {
    final isSelected = _lactationStage == value;
    return GestureDetector(
      onTap: () => setState(() => _lactationStage = value),
      child: Container(
        padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(50.0)),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.white : AppColors.primaryGreen,
              size: AppSizes.icon20,
            ),
            SizedBox(width: context.responsiveSpacing(AppSizes.spacing12)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.responsiveFontSize(14.0),
                fontWeight: FontWeight.w400,
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
