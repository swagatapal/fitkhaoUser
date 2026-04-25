import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/meal_plan_model.dart';
import '../../providers/meal_plan_provider.dart';

class MealPlanWidget extends ConsumerStatefulWidget {
  const MealPlanWidget({super.key});

  @override
  ConsumerState<MealPlanWidget> createState() => _MealPlanWidgetState();
}

class _MealPlanWidgetState extends ConsumerState<MealPlanWidget>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  TabController? _tabController;
  List<MealPlanMeal> _currentMeals = [];
  int _selectedTabIndex = 0;

  static const _categoryOrder = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  List<MealPlanMeal> _sortedMeals(List<MealPlanMeal> meals) {
    final sorted = [...meals];
    sorted.sort((a, b) {
      final ai = _categoryOrder.indexOf(a.category.dishCategory);
      final bi = _categoryOrder.indexOf(b.category.dishCategory);
      return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
    });
    return sorted;
  }

  void _updateTabController(List<MealPlanMeal> meals) {
    final sorted = _sortedMeals(meals);
    if (_tabController == null || _tabController!.length != sorted.length) {
      _tabController?.dispose();
      _tabController = TabController(length: sorted.length, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() => _selectedTabIndex = _tabController!.index);
        }
      });
    }
    _currentMeals = sorted;
    _selectedTabIndex = 0;
    _tabController!.index = 0;
  }

  void _onDateSelected(DateTime date, MealPlan mealPlan) {
    final day = mealPlan.dayForDate(date);
    setState(() {
      _selectedDate = date;
      if (day != null && day.meals.isNotEmpty) {
        _updateTabController(day.meals);
      } else {
        _tabController?.dispose();
        _tabController = null;
        _currentMeals = [];
        _selectedTabIndex = 0;
      }
    });
  }

  Future<void> _showCalendar(
      BuildContext context, MealPlan mealPlan) async {
    final available = mealPlan.availableDates;
    if (available.isEmpty) return;

    final first = available.first;
    final last = available.last;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(last)
          ? last
          : _selectedDate.isBefore(first)
              ? first
              : _selectedDate,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (day) {
        final d = DateTime(day.year, day.month, day.day);
        return available.contains(d);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
              surface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      _onDateSelected(picked, mealPlan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealPlanProvider);

    if (state.isLoading) {
      return _buildSkeleton();
    }

    if (state.error != null) {
      return _buildError(state.error!);
    }

    if (state.mealPlan == null || state.mealPlan!.days.isEmpty) {
      return _buildNoMealPlan();
    }

    final mealPlan = state.mealPlan!;

    // Initialise selected date + tabs on first valid data load
    if (_tabController == null) {
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final available = mealPlan.availableDates;
      // Pick today if available, else the closest upcoming date, else first
      DateTime initial;
      if (available.contains(today)) {
        initial = today;
      } else {
        final upcoming = available.where((d) => d.isAfter(today));
        initial = upcoming.isNotEmpty ? upcoming.first : available.first;
      }
      _selectedDate = initial;
      final day = mealPlan.dayForDate(initial);
      if (day != null && day.meals.isNotEmpty) {
        _updateTabController(day.meals);
      }
    }

    final day = mealPlan.dayForDate(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, mealPlan),
        const SizedBox(height: AppSizes.spacing12),
        if (day == null || day.meals.isEmpty)
          _buildNoDayData()
        else
          _buildMealContent(day),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, MealPlan mealPlan) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'My Meal Plan',
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
        ),
        // Date display chip
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing10,
            vertical: AppSizes.spacing4,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radius4),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            _formatDate(_selectedDate),
            style: const TextStyle(
              fontSize: AppTypography.fontSize12,
              fontWeight: AppTypography.semiBold,
              color: AppColors.primaryGreen,
              fontFamily: 'Lato',
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spacing8),
        // Calendar picker button
        GestureDetector(
          onTap: () => _showCalendar(context, mealPlan),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.spacing6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(AppSizes.radius4),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealContent(MealPlanDay day) {
    if (_tabController == null || _currentMeals.isEmpty) {
      return _buildNoDayData();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal category tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(
              fontSize: AppTypography.fontSize13,
              fontWeight: AppTypography.semiBold,
              fontFamily: 'Lato',
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: AppTypography.fontSize13,
              fontWeight: AppTypography.regular,
              fontFamily: 'Lato',
            ),
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryGreen,
            indicatorWeight: 2.5,
            dividerColor: AppColors.borderColor,
            tabs: _currentMeals
                .map((m) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _categoryIcon(m.category.dishCategory),
                          const SizedBox(width: 4),
                          Text(m.category.dishCategory),
                        ],
                      ),
                    ))
                .toList(),
          ),
          // Tab content — IndexedStack so height is intrinsic (no fixed height needed)
          IndexedStack(
            index: _selectedTabIndex.clamp(0, _currentMeals.length - 1),
            children: _currentMeals
                .map((m) => _buildDishList(m.dishes))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDishList(List<MealPlanDish> dishes) {
    if (dishes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSizes.spacing24),
          child: Text(
            'No dishes assigned for this meal',
            style: TextStyle(
              fontSize: AppTypography.fontSize13,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing8,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dishes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildDishRow(dishes[index]),
    );
  }

  Widget _buildDishRow(MealPlanDish dish) {
    final typeLabel =
        dish.dishTypes.isNotEmpty ? dish.dishTypes.first.dishType : '';
    final isVeg = dish.isVeg;
    final dotColor = isVeg ? const Color(0xFF388E3C) : const Color(0xFFD32F2F);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FSSAI veg/non-veg indicator
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                border: Border.all(color: dotColor, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.dishName,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (typeLabel.isNotEmpty) ...[
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize10,
                          color: dotColor,
                          fontFamily: 'Lato',
                          fontWeight: AppTypography.medium,
                        ),
                      ),
                      const Text(' • ',
                          style: TextStyle(
                              color: AppColors.textTertiary, fontSize: 10)),
                    ],
                    if (dish.nutrition.kcal > 0)
                      Text(
                        '${dish.nutrition.kcal.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize10,
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                  ],
                ),
                if (dish.nutrition.protein > 0 ||
                    dish.nutrition.carbs > 0 ||
                    dish.nutrition.fat > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: AppSizes.spacing6,
                      children: [
                        if (dish.nutrition.protein > 0)
                          _macroChip('P',
                              dish.nutrition.protein.toStringAsFixed(1),
                              const Color(0xFF4A7C3E)),
                        if (dish.nutrition.carbs > 0)
                          _macroChip('C',
                              dish.nutrition.carbs.toStringAsFixed(1),
                              const Color(0xFFC66301)),
                        if (dish.nutrition.fat > 0)
                          _macroChip('F', dish.nutrition.fat.toStringAsFixed(1),
                              const Color(0xFF6BA84F)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${dish.marketPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize13,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.primaryGreen,
                  fontFamily: 'Lato',
                ),
              ),
              Text(
                dish.orderMeasuringUnit,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize10,
                  color: AppColors.textTertiary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
      child: Text(
        '$label: ${value}g',
        style: TextStyle(
          fontSize: 9,
          fontWeight: AppTypography.semiBold,
          color: color,
          fontFamily: 'Lato',
        ),
      ),
    );
  }

  Widget _categoryIcon(String category) {
    IconData icon;
    switch (category.toLowerCase()) {
      case 'breakfast':
        icon = Icons.wb_sunny_outlined;
        break;
      case 'lunch':
        icon = Icons.lunch_dining_outlined;
        break;
      case 'snacks':
        icon = Icons.cookie_outlined;
        break;
      case 'dinner':
        icon = Icons.nightlight_outlined;
        break;
      default:
        icon = Icons.restaurant_outlined;
    }
    return Icon(icon, size: 14);
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 100, height: 16,
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4))),
            const Spacer(),
            Container(
                width: 80, height: 28,
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4))),
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.errorColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.errorColor, size: AppSizes.icon20),
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
            onTap: () =>
                ref.read(mealPlanProvider.notifier).refresh(),
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

  Widget _buildNoMealPlan() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu_outlined,
            size: AppSizes.icon48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSizes.spacing12),
          const Text(
            'No meal plan assigned yet',
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing6),
          const Text(
            'Your nutritionist will assign a personalised\nmeal plan once your subscription is active.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDayData() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing24),
      alignment: Alignment.center,
      child: const Text(
        'No meal plan available for this date',
        style: TextStyle(
          fontSize: AppTypography.fontSize13,
          color: AppColors.textSecondary,
          fontFamily: 'Lato',
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
