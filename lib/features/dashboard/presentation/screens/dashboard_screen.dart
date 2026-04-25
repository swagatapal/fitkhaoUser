import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../delivery/providers/nutrition_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../widgets/meal_plan_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      ref.read(authProvider.notifier).loadProfile(),
      ref.read(nutritionProgressProvider.notifier).getDailyNutritionProgress(),
      ref.read(mealPlanProvider.notifier).loadMealPlan(),
    ]);
  }

  bool _hasNutritionalTargets() {
    final auth = ref.watch(authProvider);
    return auth.targetProtein != null &&
        auth.targetFat != null &&
        auth.targetCarbs != null &&
        auth.targetKCalories != null;
  }

  String _formattedLastUpdated() {
    final lastUpdated = ref.watch(authProvider).lastUpdatedTargetKCal;
    if (lastUpdated == null) return '';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final day = lastUpdated.day;
    final suffix = (day == 1 || day == 21 || day == 31)
        ? 'st'
        : (day == 2 || day == 22)
            ? 'nd'
            : (day == 3 || day == 23)
                ? 'rd'
                : 'th';
    return '$day$suffix ${months[lastUpdated.month - 1]}';
  }

  Color _progressColor(int percentage) {
    if (percentage >= 100) return const Color(0xFFD32F2F);
    if (percentage >= 80) return const Color(0xFFFF9800);
    if (percentage >= 50) return const Color(0xFF4A7C3E);
    return const Color(0xFF6BA84F);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPaddingHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSizes.spacing16),
                _buildHeader(),
                const SizedBox(height: AppSizes.spacing20),
                if (_hasNutritionalTargets()) ...[
                  _buildNutritionalTargetsSection(),
                  const SizedBox(height: AppSizes.spacing32),
                ] else
                  _buildNoTargetsPlaceholder(),
                _buildMealPlanSection(),
                const SizedBox(height: AppSizes.spacing32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final formattedDate = _formattedLastUpdated();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'My Progress',
          style: TextStyle(
            fontSize: AppTypography.fontSize20,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        if (formattedDate.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing12,
              vertical: AppSizes.spacing6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFC66301),
              borderRadius: BorderRadius.circular(AppSizes.radius4),
            ),
            child: Text(
              'Updated $formattedDate',
              style: const TextStyle(
                fontSize: AppTypography.fontSize12,
                fontWeight: AppTypography.medium,
                color: Colors.white,
                fontFamily: 'Lato',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNutritionalTargetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nutritional Targets',
          style: TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: AppTypography.semiBold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        _buildNutritionProgress(),
      ],
    );
  }

  Widget _buildNutritionProgress() {
    final progressState = ref.watch(nutritionProgressProvider);

    if (progressState.isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (progressState.error != null) {
      return _buildErrorState(progressState.error!);
    }

    if (progressState.progressData == null) {
      return const SizedBox.shrink();
    }

    final targets = progressState.progressData!.targets;
    final progress = progressState.progressData!.progress;

    return Column(
      children: [
        _buildCaloriesCard(
          consumed: progress.calories.consumed,
          target: targets.calories,
          remaining: progress.calories.remaining,
          percentage: progress.calories.percentage,
        ),
        const SizedBox(height: AppSizes.spacing12),
        Row(
          children: [
            Expanded(
              child: _buildMacroCard(
                label: 'Protein',
                consumed: progress.protein.consumed,
                target: targets.protein,
                percentage: progress.protein.percentage,
                unit: 'g',
                color: const Color(0xFF4A7C3E),
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: _buildMacroCard(
                label: 'Carbs',
                consumed: progress.carbs.consumed,
                target: targets.carbs,
                percentage: progress.carbs.percentage,
                unit: 'g',
                color: const Color(0xFFC66301),
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: _buildMacroCard(
                label: 'Fat',
                consumed: progress.fat.consumed,
                target: targets.fat,
                percentage: progress.fat.percentage,
                unit: 'g',
                color: const Color(0xFF6BA84F),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCaloriesCard({
    required double consumed,
    required double target,
    required double remaining,
    required int percentage,
  }) {
    final color = _progressColor(percentage);
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.1),
            AppColors.primaryGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Calories',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.medium,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize20,
                        fontWeight: AppTypography.bold,
                        color: AppColors.primaryGreen,
                        fontFamily: 'Lato',
                      ),
                      children: [
                        TextSpan(text: consumed.toStringAsFixed(0)),
                        const TextSpan(
                          text: ' / ',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize16,
                            fontWeight: AppTypography.medium,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextSpan(
                          text: target.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const TextSpan(
                          text: ' kcal',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.medium,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing12,
                  vertical: AppSizes.spacing4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppSizes.radius20),
                ),
                child: Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    color: Colors.white,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radius4),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining: ${remaining.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.medium,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
              const Icon(
                Icons.local_fire_department,
                color: AppColors.primaryGreen,
                size: AppSizes.icon20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard({
    required String label,
    required double consumed,
    required double target,
    required int percentage,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: AppSizes.shadowBlur10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 50,
            width: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _progressColor(percentage),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize10,
                    fontWeight: AppTypography.semiBold,
                    color: color,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    color: color,
                    fontFamily: 'Lato',
                  ),
                  children: [
                    TextSpan(text: consumed.toStringAsFixed(1)),
                    TextSpan(
                      text: unit,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize10,
                        fontWeight: AppTypography.medium,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                ' /${target.toStringAsFixed(0)}$unit',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize10,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing2),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTypography.fontSize10,
              fontWeight: AppTypography.medium,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.errorColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.errorColor,
            size: AppSizes.icon20,
          ),
          const SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: AppTypography.fontSize12,
                color: AppColors.errorColor,
                fontFamily: 'Lato',
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadData,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                fontWeight: AppTypography.semiBold,
                color: AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanSection() {
    return const MealPlanWidget();
  }

  Widget _buildNoTargetsPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.track_changes_outlined,
              size: AppSizes.icon80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSizes.spacing16),
            const Text(
              'No targets set yet',
              style: TextStyle(
                fontSize: AppTypography.fontSize16,
                fontWeight: AppTypography.semiBold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            const Text(
              'Complete your health assessment to see your\nnutritional targets and daily progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
