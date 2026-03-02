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
import '../../provider/physiological_category_provider.dart';
import '../../provider/exercise_provider.dart';
import '../../provider/profession_provider.dart';

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
  // Multi-select exercise types (stores lowercased exerciseGroup values)
  final Set<String> _selectedExerciseTypes = {};
  // Per-exercise-type days/duration state & controllers
  final Map<String, String> _daysPerExercise = {};
  final Map<String, String> _durationPerExercise = {};
  final Map<String, TextEditingController> _daysCtrlMap = {};
  final Map<String, TextEditingController> _durationCtrlMap = {};

  // Physiological conditions (stores API condition codes like 't2dm', 'hypertension', etc.)
  final Set<String> _selectedConditionCodes = {};

  String _regularlyStatus =
      'constipated'; // constipated, diarrhoeal, both, none

  // Goal selection
  String _selectedGoal = 'fat-loss'; // fat-loss, lean-mass-gain, regular-bmi-maintenance

  // Controllers
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  bool _isInitialized = false;
  String? _uploadedImageUrl;

  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  // Header fully collapses when scroll offset exceeds this threshold
  static const double _collapseThreshold = 200.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load profile data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  void _onScroll() {
    final collapsed = _scrollController.offset > _collapseThreshold;
    if (collapsed != _isCollapsed) {
      setState(() => _isCollapsed = collapsed);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    for (final c in _daysCtrlMap.values) {
      c.dispose();
    }
    for (final c in _durationCtrlMap.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Load profile data and physiological categories from API
  Future<void> _loadProfileData() async {
    // Load categories and profile in parallel
    final categoryNotifier = ref.read(physiologicalCategoryProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);

    final professionNotifier = ref.read(professionProvider.notifier);
    final exerciseNotifier = ref.read(exerciseProvider.notifier);

    await Future.wait([
      categoryNotifier.loadCategories(),
      authNotifier.loadProfile(),
      professionNotifier.loadProfessions(),
      exerciseNotifier.loadExercises(),
    ]);

    if (mounted) {
      _populateFormFields();
    }
  }

  String _getSaveButtonText() {
    return AppStrings.save;
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

      // Activity level — find profession group by MongoDB _id
      if (authState.professionGroupId.isNotEmpty) {
        final professions = ref.read(professionProvider).professions;
        final matchList = professions
            .where((p) => p.id == authState.professionGroupId)
            .toList();
        if (matchList.isNotEmpty) {
          _activityLevel = matchList.first.value;
        } else if (professions.isNotEmpty) {
          _activityLevel = professions.first.value;
        }
      }

      // Exercise info
      _doesExercise = authState.doesExercise;

      // Populate exercise types from exercises array [{exerciseGroupId, daysPerWeek, hoursPerDay}]
      _selectedExerciseTypes.clear();
      final exerciseGroups = ref.read(exerciseProvider).exercises;
      for (final ex in authState.exercises) {
        final groupId = ex['exerciseGroupId'] as String? ?? '';
        if (groupId.isEmpty) continue;
        final exMatchList = exerciseGroups.where((g) => g.id == groupId).toList();
        if (exMatchList.isNotEmpty) {
          final exMatch = exMatchList.first;
          _selectedExerciseTypes.add(exMatch.value);
          _ensureExerciseControllers(exMatch.value);
          final days = ex['daysPerWeek'];
          final duration = ex['hoursPerDay'];
          if (days != null) {
            final daysStr = days.toString();
            _daysPerExercise[exMatch.value] = daysStr;
            _daysCtrlMap[exMatch.value]!.text = daysStr;
          }
          if (duration != null) {
            final durStr = duration.toString();
            _durationPerExercise[exMatch.value] = durStr;
            _durationCtrlMap[exMatch.value]!.text = durStr;
          }
        }
      }

      // Health conditions — use selectedConditionCodes from API
      _selectedConditionCodes.clear();
      _selectedConditionCodes.addAll(authState.selectedConditionCodes);

      // Regularity status
      _regularlyStatus = authState.regularityStatus.toLowerCase();

      // Selected goal
      if (authState.selectedGoal.isNotEmpty) {
        _selectedGoal = authState.selectedGoal;
      }

      _isInitialized = true;
    });
  }

  /// Lazily create days/duration controllers for an exercise type
  void _ensureExerciseControllers(String value) {
    _daysCtrlMap.putIfAbsent(value, () => TextEditingController());
    _durationCtrlMap.putIfAbsent(value, () => TextEditingController());
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
    // Build exercises array for new API format [{exerciseGroupId, daysPerWeek, hoursPerDay}]
    final exerciseGroups = ref.read(exerciseProvider).exercises;
    final exercisesList = <Map<String, dynamic>>[];
    if (_doesExercise) {
      for (final exerciseValue in _selectedExerciseTypes) {
        final matchList = exerciseGroups.where((g) => g.value == exerciseValue).toList();
        if (matchList.isNotEmpty) {
          exercisesList.add({
            'exerciseGroupId': matchList.first.id,
            'daysPerWeek': int.tryParse(_daysPerExercise[exerciseValue] ?? '') ?? 0,
            'hoursPerDay': double.tryParse(_durationPerExercise[exerciseValue] ?? '') ?? 0.0,
          });
        }
      }
    }

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

    // Get professionGroupId from the selected activity level
    final professions = ref.read(professionProvider).professions;
    final selectedProfessionList = professions.where((p) => p.value == _activityLevel).toList();
    final professionGroupId = selectedProfessionList.isNotEmpty ? selectedProfessionList.first.id : '';

    // Save selected condition codes and health info to provider
    authNotifier.saveSelectedConditions(_selectedConditionCodes.toList());

    authNotifier.saveDetailedHealthInfo(
      height: parsedHeight ?? authState.height ?? 0,
      weight: parsedWeight ?? authState.weight ?? 0,
      age: parsedAge ?? authState.age ?? 0,
      professionGroupId: professionGroupId,
      doesExercise: _doesExercise,
      exercises: exercisesList,
      pregnancy: _selectedConditionCodes.contains('p123'),
      lactation: _selectedConditionCodes.contains('l12'),
      diabetes: _selectedConditionCodes.contains('t2dm'),
      hypertension: _selectedConditionCodes.contains('hypertension'),
      cardiacProblem: _selectedConditionCodes.contains('cvd'),
      kidneyDisease: _selectedConditionCodes.contains('ckd'),
      liverRelatedProblem: false,
      otherConditions: '',
      regularityStatus: _capitalize(_regularlyStatus),
      selectedGoal: _selectedGoal,
    );

    // Get available categories for building the save payload
    final categories = ref.read(physiologicalCategoryProvider).categories;

    // Complete registration with collected data (calls PUT API)
    final success = await authNotifier.completeRegistration(
      availableCategories: categories,
    );

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

    if (authState.isLoading && !_isInitialized) {
      return Scaffold(
        //backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                strokeWidth: 3,
              ),
              const SizedBox(height: AppSizes.spacing16),
              Text(
                'Loading your profile...',
                style: TextStyle(
                  fontSize: context.responsiveFontSize(14.0),
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      //backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Collapsing header with parallax ──
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            backgroundColor: const Color(0xFF4A7D33),
            automaticallyImplyLeading: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              // Circular profile avatar — fades in when header collapses
              AnimatedOpacity(
                opacity: _isCollapsed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryGreen,
                    backgroundImage: (_uploadedImageUrl != null &&
                            _uploadedImageUrl!.isNotEmpty)
                        ? NetworkImage(_uploadedImageUrl!)
                        : const NetworkImage("https://i.sstatic.net/l60Hf.png"),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // profile history
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                child: GestureDetector(
                  onTap: () => context.push(RouteNames.profileHistory),
                  child: Container(
                    width: AppSizes.iconContainerSize,
                    height: AppSizes.iconContainerSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5D9E40),
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                    child: Center(
                      child: Icon(Icons.history, color: Colors.white,)
                    ),
                  ),
                ),
              ),
              
              // Edit button — always visible
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                child: GestureDetector(
                  onTap: () => context.push(RouteNames.editPersonalProfile),
                  child: Container(
                    width: AppSizes.iconContainerSize,
                    height: AppSizes.iconContainerSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5D9E40),
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
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



              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                child: GestureDetector(
                  onTap: _showLogoutConfirmation,
                  child: Container(
                    width: AppSizes.iconContainerSize,
                    height: AppSizes.iconContainerSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5D9E40),
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                    child: Center(
                        child: Icon(Icons.logout_outlined, color: Colors.white)
                    ),
                  ),
                ),
              ),

              
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _buildImageSection(),
            ),
          ),

          // ── Scrollable form content ──
          SliverPadding(
            padding: EdgeInsets.fromLTRB(spacing20, spacing20, spacing20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  "Select type of Physical Activity",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF2B292A),
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
                    // const SizedBox(width: 4),
                    // const Text(
                    //   "*",
                    //   style: TextStyle(
                    //     fontSize: 18,
                    //     fontWeight: FontWeight.w400,
                    //     color: Colors.red,
                    //     fontFamily: "Lato",
                    //   ),
                    // ),
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
                _buildDynamicProfessions(spacing12),
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
                        onTap: () => setState(() => _doesExercise = false),
                      ),
                    ),
                  ],
                ),

                // Exercise type list + inline days/duration per selected type
                if (_doesExercise) ...[
                  SizedBox(height: spacing16),
                  _buildSectionTitle(AppStrings.typeOfExercise),
                  SizedBox(height: spacing12),
                  _buildDynamicExerciseTypes(spacing12),
                ],

                SizedBox(height: spacing20),

                // Physiological Status Section
                Text(
                  AppStrings.selectPhysiologicalStatus,
                  style: const TextStyle(
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

                // Dynamic physiological conditions from API
                _buildDynamicConditions(),

                SizedBox(height: spacing24),

                // Regular Status Section
                _buildSectionTitle(AppStrings.areYouRegularly),
                SizedBox(height: spacing16),
                _buildRegularStatusOption(AppStrings.constipated, 'constipated'),
                SizedBox(height: spacing12),
                _buildRegularStatusOption(AppStrings.diarrhoeal, 'diarrhoeal'),
                SizedBox(height: spacing12),
                _buildRegularStatusOption(AppStrings.both, 'both'),
                SizedBox(height: spacing12),
                _buildRegularStatusOption(AppStrings.none, 'none'),

                SizedBox(height: spacing24),

                // Contact Nutritionist banner when profile updates are locked
                if (!authState.isUpdateable) ...[
                  Container(
                    padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Profile updates are locked. Please contact your nutritionist to update.',
                            style: TextStyle(
                              fontSize: context.responsiveFontSize(13.0),
                              color: Colors.orange.shade800,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.responsiveSpacing(12.0)),
                ],
                // Save Button
                PrimaryButton(
                  text: _getSaveButtonText(),
                  onPressed: authState.isUpdateable ? _handleSave : null,
                  textColor: Colors.white,
                  height: context.inputHeight,
                  isLoading: authState.isLoading,
                ),
                SizedBox(height: context.responsiveSpacing(100.0)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          title: Text(
            'Logout',
            style: TextStyle(
              fontSize: AppTypography.fontSize18,
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          content:  Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textSecondary,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: Colors.white,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Handle logout process
  Future<void> _handleLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );

      // Perform logout
      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.logout();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success && mounted) {
        // Navigate to phone auth screen and clear navigation stack
        context.go(RouteNames.phoneAuth);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: AppColors.successColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to logout. Please try again.'),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildImageSection() {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Green gradient background with pattern
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A7D33), Color(0xFF4A7D33)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Image.asset(
            "assets/images/header_bg.png",
            width: double.infinity,
            fit: BoxFit.cover,
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
              height: AppSizes.containerHeightMLarge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radius16),
                color: _uploadedImageUrl == null || _uploadedImageUrl!.isEmpty
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
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
                          return Image.network("https://i.sstatic.net/l60Hf.png", fit: BoxFit.cover);
                        },
                      )
                    : Image.network("https://i.sstatic.net/l60Hf.png", fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ],
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

  /// Build dynamic physiological conditions from API
  Widget _buildDynamicConditions() {
    final categoryState = ref.watch(physiologicalCategoryProvider);

    if (categoryState.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGreen,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (categoryState.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: categoryState.categories.map((category) {
        return _buildConditionCheckbox(category.name, category.code);
      }).toList(),
    );
  }

  /// Checkbox for a dynamic condition code
  Widget _buildConditionCheckbox(String label, String code) {
    final isChecked = _selectedConditionCodes.contains(code);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isChecked) {
            _selectedConditionCodes.remove(code);
          } else {
            _selectedConditionCodes.add(code);
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: context.responsiveFontSize(14.0),
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build dynamic profession/physical activity options from API
  Widget _buildDynamicProfessions(double spacing) {
    final professionState = ref.watch(professionProvider);

    if (professionState.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGreen,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (professionState.professions.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    for (int i = 0; i < professionState.professions.length; i++) {
      final group = professionState.professions[i];
      if (i > 0) children.add(SizedBox(height: spacing));
      children.add(
        _buildActivityOption(
          title: group.professionGroup,
          description: group.professions.join(', '),
          value: group.value,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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

  /// Build dynamic exercise type options from API (multi-select)
  Widget _buildDynamicExerciseTypes(double spacing) {
    final exerciseState = ref.watch(exerciseProvider);

    if (exerciseState.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGreen,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (exerciseState.exercises.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    for (int i = 0; i < exerciseState.exercises.length; i++) {
      final group = exerciseState.exercises[i];
      if (i > 0) children.add(SizedBox(height: spacing));
      children.add(
        _buildExerciseTypeOption(
          title: group.exerciseGroup,
          description: group.exercises.join(', '),
          value: group.value,
          daysCtrl: _daysCtrlMap[group.value],
          durationCtrl: _durationCtrlMap[group.value],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildExerciseTypeOption({
    required String title,
    required String description,
    required String value,
    TextEditingController? daysCtrl,
    TextEditingController? durationCtrl,
  }) {
    final isSelected = _selectedExerciseTypes.contains(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            if (isSelected) {
              _selectedExerciseTypes.remove(value);
            } else {
              _selectedExerciseTypes.add(value);
              _ensureExerciseControllers(value);
            }
          }),
          child: Container(
            padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(context.responsiveSpacing(4.0)),
              border: Border.all(
                color:
                    isSelected ? AppColors.primaryGreen : AppColors.borderColor,
                width: AppSizes.borderMedium,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox-style indicator for multi-select
                Container(
                  width: AppSizes.checkboxSize,
                  height: AppSizes.checkboxSize,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.borderColor,
                      width: AppSizes.borderMedium,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: AppSizes.icon14,
                        )
                      : null,
                ),
                SizedBox(
                    width: context.responsiveSpacing(AppSizes.spacing12)),
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
                    ],          // inner Column children
                  ),            // inner Column
                ),              // Expanded
              ],                // Row children
            ),                  // Row
          ),                    // Container
        ),                      // GestureDetector
        // Inline days/duration fields — shown when this exercise type is selected
        if (isSelected && daysCtrl != null) ...[
          SizedBox(height: context.responsiveSpacing(12.0)),
          _buildNumberField(
            label: AppStrings.howManyDaysWeek,
            controller: daysCtrl,
            onChanged: (v) => setState(() => _daysPerExercise[value] = v),
            maxValue: 7,
          ),
          SizedBox(height: context.responsiveSpacing(8.0)),
          _buildNumberField(
            label: AppStrings.durationInHrs,
            controller: durationCtrl!,
            onChanged: (v) => setState(() => _durationPerExercise[value] = v),
            maxValue: 24,
          ),
        ],
      ],                        // outer Column children
    );                          // Column / return
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

}
