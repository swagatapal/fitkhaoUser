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
import '../../../../shared/widgets/shimmer_effect.dart';
import '../../../auth/models/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../provider/physiological_category_provider.dart';
import '../../provider/exercise_provider.dart';
import '../../provider/profession_provider.dart';
import '../widgets/prescription_upload_section.dart';

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
  String _selectedGoal =
      'fat-loss'; // fat-loss, lean-mass-gain, regular-bmi-maintenance

  // Controllers
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  bool _isInitialized = false;

  // Wizard step (0 Personal · 1 Lifestyle · 2 Health · 3 Documents).
  int _currentStep = 0;
  static const _kStepTitles = ['Personal', 'Lifestyle', 'Health', 'Documents'];

  // ── Validation state (frontend). All fields are required except the
  // prescription attachment. Errors are surfaced inline under each field. ──
  bool _showErrors = false;
  String? _ageError;
  String? _heightError;
  String? _weightError;
  String? _exerciseTypeError; // "select at least one" when exercising
  final Map<String, String?> _daysError = {};
  final Map<String, String?> _durationError = {};

  final ScrollController _scrollController = ScrollController();

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
      if (authState.age != null && authState.age! > 0) {
        _age = _formatMetric(authState.age!);
        _ageController.text = _age;
      }
      if (authState.height != null && authState.height! > 0) {
        _heightCm = _formatMetric(authState.height!);
        _heightController.text = _heightCm;
      }
      if (authState.weight != null && authState.weight! > 0) {
        _weightKg = _formatMetric(authState.weight!);
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
        final exMatchList =
            exerciseGroups.where((g) => g.id == groupId).toList();
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

  /// Validates every mandatory field (all except the prescription attachment).
  /// Populates the inline error state and returns whether the form can be saved.
  /// When [reveal] is true the errors become visible and the view scrolls to the
  /// first problem.
  bool _validateForm({bool reveal = true}) {
    // ── Body metrics ──
    final ageText = _age.trim();
    final ageVal = double.tryParse(ageText);
    String? ageErr;
    if (ageText.isEmpty) {
      ageErr = 'Age is required';
    } else if (ageVal == null || ageVal <= 0 || ageVal > 120) {
      ageErr = 'Enter a valid age (1–120)';
    }

    final heightText = _heightCm.trim();
    final heightVal = double.tryParse(heightText);
    String? heightErr;
    if (heightText.isEmpty) {
      heightErr = 'Height is required';
    } else if (heightVal == null || heightVal <= 0 || heightVal > 300) {
      heightErr = 'Enter a valid height in cm';
    }

    final weightText = _weightKg.trim();
    final weightVal = double.tryParse(weightText);
    String? weightErr;
    if (weightText.isEmpty) {
      weightErr = 'Weight is required';
    } else if (weightVal == null || weightVal <= 0 || weightVal > 500) {
      weightErr = 'Enter a valid weight in kg';
    }

    // ── Exercise (only when the user says they exercise) ──
    String? exerciseTypeErr;
    final Map<String, String?> daysErr = {};
    final Map<String, String?> durationErr = {};
    if (_doesExercise) {
      if (_selectedExerciseTypes.isEmpty) {
        exerciseTypeErr = 'Select at least one exercise type';
      } else {
        for (final type in _selectedExerciseTypes) {
          final daysText = (_daysPerExercise[type] ?? '').trim();
          final days = int.tryParse(daysText);
          if (daysText.isEmpty) {
            daysErr[type] = 'Required';
          } else if (days == null || days < 1 || days > 7) {
            daysErr[type] = 'Enter 1–7 days';
          }

          final durText = (_durationPerExercise[type] ?? '').trim();
          final dur = double.tryParse(durText);
          if (durText.isEmpty) {
            durationErr[type] = 'Required';
          } else if (dur == null || dur <= 0 || dur > 24) {
            durationErr[type] = 'Enter 1–24 hrs';
          }
        }
      }
    }

    final isValid = ageErr == null &&
        heightErr == null &&
        weightErr == null &&
        exerciseTypeErr == null &&
        daysErr.isEmpty &&
        durationErr.isEmpty;

    if (reveal) {
      setState(() {
        _showErrors = true;
        _ageError = ageErr;
        _heightError = heightErr;
        _weightError = weightErr;
        _exerciseTypeError = exerciseTypeErr;
        _daysError
          ..clear()
          ..addAll(daysErr);
        _durationError
          ..clear()
          ..addAll(durationErr);
      });

      // Scroll up to the body-detail fields when they're the first offenders.
      if (ageErr != null || heightErr != null || weightErr != null) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }

    return isValid;
  }

  /// Validates only the Personal step (age / height / weight).
  bool _validatePersonalStep() {
    final ageText = _age.trim();
    final ageVal = double.tryParse(ageText);
    String? ageErr;
    if (ageText.isEmpty) {
      ageErr = 'Age is required';
    } else if (ageVal == null || ageVal <= 0 || ageVal > 120) {
      ageErr = 'Enter a valid age (1–120)';
    }

    final heightText = _heightCm.trim();
    final heightVal = double.tryParse(heightText);
    String? heightErr;
    if (heightText.isEmpty) {
      heightErr = 'Height is required';
    } else if (heightVal == null || heightVal <= 0 || heightVal > 300) {
      heightErr = 'Enter a valid height in cm';
    }

    final weightText = _weightKg.trim();
    final weightVal = double.tryParse(weightText);
    String? weightErr;
    if (weightText.isEmpty) {
      weightErr = 'Weight is required';
    } else if (weightVal == null || weightVal <= 0 || weightVal > 500) {
      weightErr = 'Enter a valid weight in kg';
    }

    setState(() {
      _showErrors = true;
      _ageError = ageErr;
      _heightError = heightErr;
      _weightError = weightErr;
    });
    return ageErr == null && heightErr == null && weightErr == null;
  }

  /// Validates only the Lifestyle step (exercise details when exercising).
  bool _validateLifestyleStep() {
    if (!_doesExercise) {
      setState(() {
        _exerciseTypeError = null;
        _daysError.clear();
        _durationError.clear();
      });
      return true;
    }
    String? exerciseTypeErr;
    final Map<String, String?> daysErr = {};
    final Map<String, String?> durationErr = {};
    if (_selectedExerciseTypes.isEmpty) {
      exerciseTypeErr = 'Select at least one exercise type';
    } else {
      for (final type in _selectedExerciseTypes) {
        final daysText = (_daysPerExercise[type] ?? '').trim();
        final days = int.tryParse(daysText);
        if (daysText.isEmpty) {
          daysErr[type] = 'Required';
        } else if (days == null || days < 1 || days > 7) {
          daysErr[type] = 'Enter 1–7 days';
        }
        final durText = (_durationPerExercise[type] ?? '').trim();
        final dur = double.tryParse(durText);
        if (durText.isEmpty) {
          durationErr[type] = 'Required';
        } else if (dur == null || dur <= 0 || dur > 24) {
          durationErr[type] = 'Enter 1–24 hrs';
        }
      }
    }
    setState(() {
      _showErrors = true;
      _exerciseTypeError = exerciseTypeErr;
      _daysError
        ..clear()
        ..addAll(daysErr);
      _durationError
        ..clear()
        ..addAll(durationErr);
    });
    return exerciseTypeErr == null && daysErr.isEmpty && durationErr.isEmpty;
  }

  void _showValidationSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fill all required fields to continue.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Advances to the next step, validating the current one first.
  void _onNext() {
    bool ok = true;
    if (_currentStep == 0) ok = _validatePersonalStep();
    if (_currentStep == 1) ok = _validateLifestyleStep();
    if (!ok) {
      _showValidationSnack();
      return;
    }
    setState(() => _currentStep = (_currentStep + 1).clamp(0, 3));
    _scrollController.jumpTo(0);
  }

  void _onBack() {
    setState(() => _currentStep = (_currentStep - 1).clamp(0, 3));
    _scrollController.jumpTo(0);
  }

  Future<void> _handleSave() async {
    if (!_validateForm()) {
      // Jump back to the first step that has an error so it's visible.
      final personalBad =
          _ageError != null || _heightError != null || _weightError != null;
      final lifestyleBad = _exerciseTypeError != null ||
          _daysError.isNotEmpty ||
          _durationError.isNotEmpty;
      setState(() {
        if (personalBad) {
          _currentStep = 0;
        } else if (lifestyleBad) {
          _currentStep = 1;
        }
      });
      _showValidationSnack();
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    final authState = ref.read(authProvider);

    // Parse optional numeric fields
    final parsedAge = _age.isNotEmpty ? double.tryParse(_age) : null;
    final parsedHeight =
        _heightCm.isNotEmpty ? double.tryParse(_heightCm) : null;
    final parsedWeight =
        _weightKg.isNotEmpty ? double.tryParse(_weightKg) : null;
    // Build exercises array for new API format [{exerciseGroupId, daysPerWeek, hoursPerDay}]
    final exerciseGroups = ref.read(exerciseProvider).exercises;
    final exercisesList = <Map<String, dynamic>>[];
    if (_doesExercise) {
      for (final exerciseValue in _selectedExerciseTypes) {
        final matchList =
            exerciseGroups.where((g) => g.value == exerciseValue).toList();
        if (matchList.isNotEmpty) {
          exercisesList.add({
            'exerciseGroupId': matchList.first.id,
            'daysPerWeek':
                int.tryParse(_daysPerExercise[exerciseValue] ?? '') ?? 0,
            'hoursPerDay':
                double.tryParse(_durationPerExercise[exerciseValue] ?? '') ??
                    0.0,
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
    if (parsedAge != null ||
        parsedHeight != null ||
        parsedWeight != null ||
        dateOfBirth != null) {
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
    final selectedProfessionList =
        professions.where((p) => p.value == _activityLevel).toList();
    final professionGroupId = selectedProfessionList.isNotEmpty
        ? selectedProfessionList.first.id
        : '';

    // Resolve the "General" code — used as the default when nothing is selected
    String generalCode = '';
    for (final c in ref.read(physiologicalCategoryProvider).categories) {
      if (c.name.toLowerCase() == 'general') {
        generalCode = c.code;
        break;
      }
    }

    // Build effective condition codes: fall back to General if none selected
    final effectiveCodes = Set<String>.from(_selectedConditionCodes);
    if (effectiveCodes.isEmpty && generalCode.isNotEmpty) {
      effectiveCodes.add(generalCode);
    }

    // Save selected condition codes and health info to provider
    authNotifier.saveSelectedConditions(effectiveCodes.toList());

    authNotifier.saveDetailedHealthInfo(
      height: parsedHeight ?? authState.height ?? 0,
      weight: parsedWeight ?? authState.weight ?? 0,
      age: parsedAge ?? authState.age ?? 0,
      professionGroupId: professionGroupId,
      doesExercise: _doesExercise,
      exercises: exercisesList,
      pregnancy: effectiveCodes.contains('p123'),
      lactation: effectiveCodes.contains('l12'),
      diabetes: effectiveCodes.contains('t2dm'),
      hypertension: effectiveCodes.contains('hypertension'),
      cardiacProblem: effectiveCodes.contains('cvd'),
      kidneyDisease: effectiveCodes.contains('ckd'),
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

  /// Formats a body metric (age/height/weight) for display: whole numbers show
  /// without a decimal (e.g. 60), fractional values keep their decimals with
  /// trailing zeros stripped (e.g. 12.50 → "12.5").
  String _formatMetric(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
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

    final spacing16 = context.responsiveSpacing(16.0);
    final spacing20 = context.responsiveSpacing(20.0);
    final spacing24 = context.responsiveSpacing(24.0);

    // Single scaffold: the app bar stays static while the body swaps between
    // the skeleton loader (initial fetch) and the wizard content.
    final isLoading = authState.isLoading && !_isInitialized;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: isLoading
          ? CustomScrollView(
              slivers: [
                _buildSkeletonFormContent(),
              ],
            )
          : Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        spacing20, spacing16, spacing20, spacing24),
                    child: _buildStepContent(authState),
                  ),
                ),
                _buildBottomBar(authState),
              ],
            ),
    );
  }

  // ─── Wizard scaffolding ───

  /// Green app bar with a back button and the screen title — matches the
  /// original pinned app bar (status bar tinted green, white content).
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF4A7D33),
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF5D9E40),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: AppSizes.icon20,
            ),
          ),
        ),
      ),
      title: const Text(
        'Health Profile',
        style: TextStyle(
          fontSize: AppTypography.fontSize18,
          fontWeight: AppTypography.bold,
          color: Colors.white,
          fontFamily: 'Lato',
        ),
      ),
    );
  }

  /// Four-step progress indicator (Personal · Lifestyle · Health · Documents).
  Widget _buildStepIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveSpacing(12.0),
        vertical: context.responsiveSpacing(16.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          _kStepTitles.length,
          (i) => Expanded(child: _buildStepColumn(i)),
        ),
      ),
    );
  }

  Widget _buildStepColumn(int index) {
    final isCompleted = index < _currentStep;
    final isCurrent = index == _currentStep;
    final isFirst = index == 0;
    final isLast = index == _kStepTitles.length - 1;
    const grey = Color(0xFFCBD5E1);
    const greyText = Color(0xFF94A3B8);
    final green = AppColors.primaryGreen;

    Color connector(bool reached) => reached ? green : grey;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 2,
                color: isFirst
                    ? Colors.transparent
                    : connector(index <= _currentStep),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isCompleted || isCurrent) ? green : Colors.white,
                border: Border.all(
                  color: (isCompleted || isCurrent) ? green : grey,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : greyText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          fontFamily: 'Lato',
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                color: isLast
                    ? Colors.transparent
                    : connector(index < _currentStep),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                _kStepTitles[index],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.responsiveFontSize(11.0),
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: (isCompleted || isCurrent) ? green : greyText,
                  fontFamily: 'Lato',
                ),
              ),
            ),
            if (isCompleted) ...[
              const SizedBox(width: 2),
              Icon(Icons.check, size: 12, color: green),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStepContent(AuthState authState) {
    switch (_currentStep) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildLifestyleStep();
      case 2:
        return _buildHealthStep();
      default:
        return _buildDocumentsStep(authState);
    }
  }

  /// Bottom navigation bar: Back / Next per step, Save Profile on the last step.
  Widget _buildBottomBar(AuthState authState) {
    final isLast = _currentStep == _kStepTitles.length - 1;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    Widget nextButton() => SizedBox(
          height: context.inputHeight,
          child: ElevatedButton(
            onPressed: _onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Lato',
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        );

    Widget backButton() => SizedBox(
          height: context.inputHeight,
          child: OutlinedButton(
            onPressed: _onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(
                color: AppColors.primaryGreen,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back, size: 18),
                SizedBox(width: 6),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
        );

    final saveButton = PrimaryButton(
      text: _getSaveButtonText(),
      onPressed: authState.isUpdateable ? _handleSave : null,
      textColor: Colors.white,
      height: context.inputHeight,
      isLoading: authState.isLoading,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.responsiveSpacing(20.0),
        context.responsiveSpacing(12.0),
        context.responsiveSpacing(20.0),
        context.responsiveSpacing(12.0) + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(child: backButton()),
            SizedBox(width: context.responsiveSpacing(12.0)),
          ],
          Expanded(child: isLast ? saveButton : nextButton()),
        ],
      ),
    );
  }

  // ─── Step content ───

  Widget _buildStepHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: context.responsiveFontSize(20.0),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2B292A),
            fontFamily: 'Lato',
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: context.responsiveSpacing(4.0)),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: context.responsiveFontSize(13.0),
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBlockHeading(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: context.responsiveFontSize(16.0),
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2B292A),
        fontFamily: 'Lato',
      ),
    );
  }

  // Step 1 · Personal — body metrics + goal.
  Widget _buildPersonalStep() {
    final spacing12 = context.responsiveSpacing(12.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing24 = context.responsiveSpacing(24.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading('Personal Details', 'Tell us a bit about yourself'),
        SizedBox(height: spacing16),
        _buildNumberField(
          label: AppStrings.ageDetails,
          controller: _ageController,
          isRequired: true,
          errorText: _ageError,
          onChanged: (value) => setState(() {
            _age = value;
            if (_showErrors) _ageError = null;
          }),
        ),
        SizedBox(height: spacing12),
        _buildNumberField(
          label: AppStrings.heightInCms,
          controller: _heightController,
          isRequired: true,
          errorText: _heightError,
          onChanged: (value) => setState(() {
            _heightCm = value;
            if (_showErrors) _heightError = null;
          }),
        ),
        SizedBox(height: spacing12),
        _buildNumberField(
          label: AppStrings.weightInKg,
          controller: _weightController,
          isRequired: true,
          errorText: _weightError,
          onChanged: (value) => setState(() {
            _weightKg = value;
            if (_showErrors) _weightError = null;
          }),
        ),
        SizedBox(height: spacing24),
        _buildBlockHeading('Select Goal'),
        SizedBox(height: spacing12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildGoalOption(
                  title: 'Lose Fat',
                  value: 'fat-loss',
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
              SizedBox(width: spacing12),
              Expanded(
                child: _buildGoalOption(
                  title: 'Gain Muscle',
                  value: 'lean-mass-gain',
                  icon: Icons.fitness_center,
                ),
              ),
              SizedBox(width: spacing12),
              Expanded(
                child: _buildGoalOption(
                  title: 'Maintain Weight',
                  value: 'regular-bmi-maintenance',
                  icon: Icons.balance_outlined,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 2 · Lifestyle — activity level + exercise.
  Widget _buildLifestyleStep() {
    final spacing12 = context.responsiveSpacing(12.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing24 = context.responsiveSpacing(24.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading('Activity Level', 'Select your usual physical work'),
        SizedBox(height: spacing16),
        _buildDynamicProfessions(spacing12),
        SizedBox(height: spacing24),
        _buildBlockHeading('Exercise Habit'),
        SizedBox(height: spacing12),
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
                onTap: () => setState(() {
                  _doesExercise = false;
                  _exerciseTypeError = null;
                  _daysError.clear();
                  _durationError.clear();
                }),
              ),
            ),
          ],
        ),
        if (_doesExercise) ...[
          SizedBox(height: spacing16),
          _buildBlockHeading(AppStrings.typeOfExercise),
          SizedBox(height: spacing12),
          _buildDynamicExerciseTypes(spacing12),
        ],
      ],
    );
  }

  // Step 3 · Health — medical conditions + digestive status.
  Widget _buildHealthStep() {
    final spacing12 = context.responsiveSpacing(12.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing24 = context.responsiveSpacing(24.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading('Medical Conditions', 'Select all that apply to you'),
        SizedBox(height: spacing16),
        _buildConditionsGrid(),
        SizedBox(height: spacing24),
        _buildBlockHeading(AppStrings.areYouRegularly),
        SizedBox(height: spacing12),
        _buildRegularStatusOption(AppStrings.constipated, 'constipated'),
        SizedBox(height: spacing12),
        _buildRegularStatusOption(AppStrings.diarrhoeal, 'diarrhoeal'),
        SizedBox(height: spacing12),
        _buildRegularStatusOption(AppStrings.both, 'both'),
        SizedBox(height: spacing12),
        _buildRegularStatusOption(AppStrings.none, 'none'),
        SizedBox(height: spacing16),
      ],
    );
  }

  // Step 4 · Documents — upload medical records.
  Widget _buildDocumentsStep(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeading(
            'Upload Documents', 'Add prescriptions or lab reports (optional)'),
        SizedBox(height: context.responsiveSpacing(16.0)),
        const PrescriptionUploadSection(),
        if (!authState.isUpdateable) ...[
          SizedBox(height: context.responsiveSpacing(16.0)),
          Container(
            padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 20),
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
        ],
      ],
    );
  }

  // ─── Skeleton/Loading State Builders ───

  Widget _buildSkeletonFormContent() {
    final spacing12 = context.responsiveSpacing(12.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing20 = context.responsiveSpacing(20.0);
    final spacing24 = context.responsiveSpacing(24.0);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(spacing20, spacing20, spacing20, spacing20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Title
          _buildSkeletonBox(width: 200, height: 24, borderRadius: 4),
          SizedBox(height: spacing16),

          // Body Details Section
          _buildSkeletonSectionHeader(),
          SizedBox(height: spacing12),
          _buildSkeletonFormField(),
          SizedBox(height: spacing12),
          _buildSkeletonFormField(),
          SizedBox(height: spacing12),
          _buildSkeletonFormField(),
          SizedBox(height: spacing16),

          // Goal Selection Section
          _buildSkeletonSectionHeader(),
          SizedBox(height: spacing12),
          Row(
            children: [
              Expanded(
                child: _buildSkeletonBox(height: 50, borderRadius: 50),
              ),
              SizedBox(width: spacing12),
              Expanded(
                child: _buildSkeletonBox(height: 50, borderRadius: 50),
              ),
            ],
          ),
          SizedBox(height: spacing12),
          _buildSkeletonBox(height: 50, borderRadius: 50),
          SizedBox(height: spacing16),

          // Activity Level Section
          _buildSkeletonSectionHeader(),
          SizedBox(height: spacing16),
          _buildSkeletonActivityOption(),
          SizedBox(height: spacing12),
          _buildSkeletonActivityOption(),
          SizedBox(height: spacing16),

          // Exercise Section
          _buildSkeletonSectionHeader(),
          SizedBox(height: spacing16),
          Row(
            children: [
              Expanded(
                child: _buildSkeletonBox(height: 50, borderRadius: 8),
              ),
              SizedBox(width: spacing12),
              Expanded(
                child: _buildSkeletonBox(height: 50, borderRadius: 8),
              ),
            ],
          ),
          SizedBox(height: spacing16),

          // Physiological Conditions Section
          _buildSkeletonSectionHeader(),
          SizedBox(height: spacing12),
          _buildSkeletonBox(width: 250, height: 20, borderRadius: 4),
          SizedBox(height: spacing12),
          _buildSkeletonConditionCheckbox(),
          SizedBox(height: spacing12),
          _buildSkeletonConditionCheckbox(),
          SizedBox(height: spacing12),
          _buildSkeletonConditionCheckbox(),
          SizedBox(height: spacing16),

          // Regular Status Section
          _buildSkeletonSectionHeader(),
          SizedBox(height: spacing16),
          _buildSkeletonRadioOption(),
          SizedBox(height: spacing12),
          _buildSkeletonRadioOption(),
          SizedBox(height: spacing12),
          _buildSkeletonRadioOption(),
          SizedBox(height: spacing24),

          // Save Button
          _buildSkeletonBox(height: context.inputHeight, borderRadius: 8),
          SizedBox(height: spacing20),
        ]),
      ),
    );
  }

  Widget _buildSkeletonBox({
    double? width,
    double? height = 20,
    double borderRadius = 4,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: ShimmerEffect(
          child: Container(color: Colors.grey.shade100),
        ),
      ),
    );
  }

  Widget _buildSkeletonSectionHeader() {
    return _buildSkeletonBox(width: 180, height: 24, borderRadius: 4);
  }

  Widget _buildSkeletonFormField() {
    final spacing = context.responsiveSpacing(8.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSkeletonBox(width: 100, height: 18, borderRadius: 4),
        SizedBox(height: spacing),
        _buildSkeletonBox(height: 50, borderRadius: 4),
      ],
    );
  }

  Widget _buildSkeletonActivityOption() {
    final spacing = context.responsiveSpacing(12.0);
    return Container(
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _buildSkeletonBox(width: 24, height: 24, borderRadius: 4),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(width: 120, height: 18, borderRadius: 4),
                SizedBox(height: 8),
                _buildSkeletonBox(width: 180, height: 16, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonConditionCheckbox() {
    return Row(
      children: [
        _buildSkeletonBox(width: 20, height: 20, borderRadius: 4),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSkeletonBox(width: 150, height: 18, borderRadius: 4),
        ),
      ],
    );
  }

  Widget _buildSkeletonRadioOption() {
    final spacing = context.responsiveSpacing(12.0);
    return Container(
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _buildSkeletonBox(width: 24, height: 24, borderRadius: 4),
          SizedBox(width: spacing),
          Expanded(
            child: _buildSkeletonBox(width: 120, height: 18, borderRadius: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required Function(String) onChanged,
    int? maxValue,
    bool isRequired = false,
    String? errorText,
  }) {
    final hasError = errorText != null;
    final radius = BorderRadius.circular(context.responsiveSpacing(4.0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: context.responsiveFontSize(14.0),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
              fontFamily: 'Lato',
            ),
            children: isRequired
                ? const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.errorColor),
                    ),
                  ]
                : null,
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
              borderRadius: radius,
              borderSide: BorderSide(
                color: hasError ? AppColors.errorColor : AppColors.borderColor,
                width: AppSizes.borderNormal,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: hasError ? AppColors.errorColor : AppColors.primaryGreen,
                width: AppSizes.borderMedium,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: context.responsiveSpacing(4.0)),
          Text(
            errorText,
            style: TextStyle(
              fontSize: context.responsiveFontSize(12.0),
              color: AppColors.errorColor,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ],
    );
  }

  /// Build dynamic physiological conditions from the API as a 2-column grid.
  Widget _buildConditionsGrid() {
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

    // Find "General" category code — used as default when nothing else is selected
    String generalCode = '';
    for (final c in categoryState.categories) {
      if (c.name.toLowerCase() == 'general') {
        generalCode = c.code;
        break;
      }
    }

    // Filter out "General" — it is implicit and should not appear in the UI
    final displayCategories = categoryState.categories
        .where((c) => c.name.toLowerCase() != 'general')
        .toList();

    if (displayCategories.isEmpty) return const SizedBox.shrink();

    final spacing = context.responsiveSpacing(12.0);
    final rows = <Widget>[];
    for (int i = 0; i < displayCategories.length; i += 2) {
      final left = displayCategories[i];
      final right =
          i + 1 < displayCategories.length ? displayCategories[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildConditionCard(left.name, left.code,
                      generalCode: generalCode),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: right != null
                      ? _buildConditionCard(right.name, right.code,
                          generalCode: generalCode)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  /// Bordered checkbox card for a dynamic condition code.
  /// [generalCode] is the code for the hidden "General" category — it is
  /// automatically added when no specific condition remains selected, and
  /// removed when any specific condition is selected.
  Widget _buildConditionCard(String label, String code,
      {String generalCode = ''}) {
    final isChecked = _selectedConditionCodes.contains(code);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isChecked) {
            _selectedConditionCodes.remove(code);
            // If nothing specific remains, restore General as the default
            final hasSpecific =
                _selectedConditionCodes.any((c) => c != generalCode);
            if (!hasSpecific && generalCode.isNotEmpty) {
              _selectedConditionCodes.add(generalCode);
            }
          } else {
            _selectedConditionCodes.add(code);
            // Remove General once any specific condition is chosen
            if (generalCode.isNotEmpty) {
              _selectedConditionCodes.remove(generalCode);
            }
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
        decoration: BoxDecoration(
          color: isChecked
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(8.0)),
          border: Border.all(
            color: isChecked ? AppColors.primaryGreen : AppColors.borderColor,
            width: AppSizes.borderMedium,
          ),
        ),
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
            SizedBox(width: context.responsiveSpacing(AppSizes.spacing8)),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.responsiveFontSize(13.0),
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
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(8.0)),
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
              color:
                  isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
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
    if (_exerciseTypeError != null) {
      children.add(SizedBox(height: context.responsiveSpacing(8.0)));
      children.add(
        Text(
          _exerciseTypeError!,
          style: TextStyle(
            fontSize: context.responsiveFontSize(12.0),
            color: AppColors.errorColor,
            fontFamily: 'Lato',
          ),
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
              _daysError.remove(value);
              _durationError.remove(value);
            } else {
              _selectedExerciseTypes.add(value);
              _ensureExerciseControllers(value);
            }
            // Any change to the selection clears the "select at least one" error.
            if (_showErrors) _exerciseTypeError = null;
          }),
          child: Container(
            padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGreen.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(context.responsiveSpacing(8.0)),
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
                SizedBox(width: context.responsiveSpacing(AppSizes.spacing12)),
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
                    ], // inner Column children
                  ), // inner Column
                ), // Expanded
              ], // Row children
            ), // Row
          ), // Container
        ), // GestureDetector
        // Inline days/duration fields — shown when this exercise type is selected
        if (isSelected && daysCtrl != null) ...[
          SizedBox(height: context.responsiveSpacing(12.0)),
          _buildNumberField(
            label: AppStrings.howManyDaysWeek,
            controller: daysCtrl,
            isRequired: true,
            errorText: _daysError[value],
            onChanged: (v) => setState(() {
              _daysPerExercise[value] = v;
              if (_showErrors) _daysError.remove(value);
            }),
            maxValue: 7,
          ),
          SizedBox(height: context.responsiveSpacing(8.0)),
          _buildNumberField(
            label: AppStrings.durationInHrs,
            controller: durationCtrl!,
            isRequired: true,
            errorText: _durationError[value],
            onChanged: (v) => setState(() {
              _durationPerExercise[value] = v;
              if (_showErrors) _durationError.remove(value);
            }),
            maxValue: 24,
          ),
        ],
      ], // outer Column children
    ); // Column / return
  }

  Widget _buildRegularStatusOption(String label, String value) {
    final isSelected = _regularlyStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _regularlyStatus = value),
      child: Container(
        padding: EdgeInsets.all(context.responsiveSpacing(12.0)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(8.0)),
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
              color:
                  isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
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
    required IconData icon,
  }) {
    final isSelected = _selectedGoal == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveSpacing(8.0),
          vertical: context.responsiveSpacing(14.0),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(context.responsiveSpacing(12.0)),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppSizes.icon24,
              color:
                  isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
            ),
            SizedBox(height: context.responsiveSpacing(8.0)),
            Text(
              title,
              style: TextStyle(
                fontSize: context.responsiveFontSize(13.0),
                fontWeight: FontWeight.w600,
                color:
                    isSelected ? AppColors.primaryGreen : AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
