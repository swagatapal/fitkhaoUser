import 'package:fitkhao_user/core/config/app_config.dart';
import 'package:fitkhao_user/core/constants/app_colors.dart';
import 'package:fitkhao_user/core/constants/app_sizes.dart';
import 'package:fitkhao_user/core/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../providers/meal_plan_nutrition_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/meal_category_provider.dart';
import 'membership_popup.dart';

// Safe JSON helpers (local to this widget file)
String _string(dynamic value) => value?.toString() ?? '';

bool _bool(dynamic value) => value == true;

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) => value is List ? value : const <dynamic>[];

// Model Classes (keep all the model classes as they are)
class MealPlanResponse {
  final bool success;
  final String message;
  final MealPlanData data;

  MealPlanResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory MealPlanResponse.fromJson(Map<String, dynamic> json) {
    return MealPlanResponse(
      success: _bool(json['success']),
      message: _string(json['message']),
      data: MealPlanData.fromJson(_map(json['data'])),
    );
  }
}

class MealPlanData {
  final MealPlan mealPlan;

  MealPlanData({required this.mealPlan});

  factory MealPlanData.fromJson(Map<String, dynamic> json) {
    return MealPlanData(
      mealPlan: MealPlan.fromJson(_map(json['mealPlan'])),
    );
  }
}

class MealPlan {
  final String id;
  final List<DayMeal> days;

  MealPlan({required this.id, required this.days});

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: _string(json['_id']),
      days: _list(json['days'])
          .whereType<Map>()
          .map((day) => DayMeal.fromJson(Map<String, dynamic>.from(day)))
          .toList(),
    );
  }
}

class DayMeal {
  final DateTime date;
  final bool isDeleted;
  final List<MealCategory> meals;

  DayMeal({
    required this.date,
    required this.isDeleted,
    required this.meals,
  });

  factory DayMeal.fromJson(Map<String, dynamic> json) {
    return DayMeal(
      date: _date(json['date']),
      isDeleted: _bool(json['isDeleted']),
      meals: _list(json['meals'])
          .whereType<Map>()
          .map((meal) => MealCategory.fromJson(Map<String, dynamic>.from(meal)))
          // Backend sometimes returns placeholder meals like:
          // { "category": {}, "dishes": [] }
          // Filter those out so UI/parsing never crashes.
          .where((meal) => !meal.isPlaceholder)
          .toList(),
    );
  }
}

class MealCategory {
  final Category category;
  final List<Dish> dishes;

  MealCategory({required this.category, required this.dishes});

  bool get isPlaceholder =>
      category.dishCategory.trim().isEmpty && dishes.isEmpty;

  factory MealCategory.fromJson(Map<String, dynamic> json) {
    return MealCategory(
      category: Category.fromJson(_map(json['category'])),
      dishes: _list(json['dishes'])
          .whereType<Map>()
          .map((dish) => Dish.fromJson(Map<String, dynamic>.from(dish)))
          .toList(),
    );
  }
}

class Category {
  final String id;
  final String dishCategory;
  final bool isActive;

  Category({
    required this.id,
    required this.dishCategory,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: _string(json['_id']),
      dishCategory: _string(json['dishCategory']),
      isActive: _bool(json['isActive']),
    );
  }
}

class DishType {
  final String id;
  final String dishType;

  DishType({required this.id, required this.dishType});

  factory DishType.fromJson(Map<String, dynamic> json) {
    return DishType(
      id: _string(json['_id']),
      dishType: _string(json['dishType']),
    );
  }
}

class Dish {
  final String id;
  final String dishCode;
  final String dishName;
  final List<DishType> dishType;
  final String remarks;
  final NutritionalValue nutritionalValue;
  final double costPrice;
  final double marketPrice;
  final bool isActive;

  Dish({
    required this.id,
    required this.dishCode,
    required this.dishName,
    required this.dishType,
    required this.remarks,
    required this.nutritionalValue,
    required this.costPrice,
    required this.marketPrice,
    required this.isActive,
  });

  /// Returns the first dish type label, e.g. "Veg" or "Non-Veg"
  String get dishTypeLabel =>
      dishType.isNotEmpty ? dishType.first.dishType : '';

  factory Dish.fromJson(Map<String, dynamic> json) {
    final rawDishType = json['dishType'];
    List<DishType> parsedDishType = [];
    if (rawDishType is List) {
      parsedDishType = rawDishType
          .whereType<Map<String, dynamic>>()
          .map(DishType.fromJson)
          .toList();
    }

    return Dish(
      id: _string(json['_id']),
      dishCode: _string(json['dishCode']),
      dishName: _string(json['dishName']),
      dishType: parsedDishType,
      remarks: _string(json['remarks']),
      nutritionalValue:
          NutritionalValue.fromJson(_map(json['nutritionalValue'])),
      costPrice: _double(json['costPrice']),
      marketPrice: _double(json['marketPrice']),
      isActive: _bool(json['isActive']),
    );
  }
}

class NutritionalValue {
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  NutritionalValue({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory NutritionalValue.fromJson(Map<String, dynamic> json) {
    return NutritionalValue(
      kcal: _double(json['kcal']),
      protein: _double(json['protein']),
      fat: _double(json['fat']),
      carbs: _double(json['carbs']),
    );
  }
}

// Main Widget - NO SCAFFOLD, NO TAB CONTROLLER
class MealPlanWidget extends ConsumerStatefulWidget {
  final String userId;

  const MealPlanWidget({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<MealPlanWidget> createState() => _MealPlanWidgetState();
}

class _MealPlanWidgetState extends ConsumerState<MealPlanWidget>
    with SingleTickerProviderStateMixin {
  MealPlanResponse? mealPlanResponse;
  DayMeal? selectedDayMeal;
  bool isLoading = true;
  String? error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ── REPLACED: TabController removed entirely.
  //    We now track the selected tab with a plain int index.
  //    TabController internally registers a ScrollPosition that competes
  //    with the parent CustomScrollView on every vertical swipe — causing
  //    the snap-back on dish cards. A plain int has zero scroll side-effects.
  int _selectedTabIndex = 0;

  final ScrollController _dateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    fetchMealPlan();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> fetchMealPlan() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final response = await http.get(
        Uri.parse(
            '${AppConfig.baseApiUrl}/api/user/${widget.userId}/meal-plan-details'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        mealPlanResponse = MealPlanResponse.fromJson(data);

        selectedDayMeal = _findNearestDayMeal();

        // Reset tab index whenever meal plan reloads
        _selectedTabIndex = 0;

        _publishMealCategories();

        final hasMealData = mealPlanResponse!.data.mealPlan.days.isNotEmpty;
        ref.read(mealPlanAvailableProvider.notifier).state = hasMealData;

        setState(() {
          isLoading = false;
        });
        _animationController.forward();
        _scrollToSelectedDate();
      } else {
        ref.read(mealPlanAvailableProvider.notifier).state = false;
        setState(() {
          error = 'Failed to load meal plan';
          isLoading = false;
        });
      }
    } catch (e) {
      ref.read(mealPlanAvailableProvider.notifier).state = false;
      setState(() {
        error = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _scrollToSelectedDate() {
    if (mealPlanResponse == null || selectedDayMeal == null) return;

    final days = mealPlanResponse!.data.mealPlan.days;
    final selectedIndex =
    days.indexWhere((d) => d.date == selectedDayMeal!.date);
    if (selectedIndex < 0) return;

    const itemWidth = 72.0;
    final targetOffset = selectedIndex * itemWidth;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dateScrollController.hasClients) {
        final maxScroll = _dateScrollController.position.maxScrollExtent;
        _dateScrollController.animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  DayMeal? _findNearestDayMeal() {
    if (mealPlanResponse == null ||
        mealPlanResponse!.data.mealPlan.days.isEmpty) {
      return null;
    }

    final days = mealPlanResponse!.data.mealPlan.days
        .where((d) => !d.isDeleted)
        .toList();
    if (days.isEmpty) return null;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (var day in days) {
      final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
      if (dayDate.isAtSameMomentAs(todayDate) && day.meals.isNotEmpty) {
        return day;
      }
    }

    DayMeal? nearestWithMeals;
    Duration? smallestWithMealsDiff;
    for (var day in days.where((d) => d.meals.isNotEmpty)) {
      final diff = day.date.difference(todayDate).abs();
      if (smallestWithMealsDiff == null || diff < smallestWithMealsDiff) {
        smallestWithMealsDiff = diff;
        nearestWithMeals = day;
      }
    }
    if (nearestWithMeals != null) return nearestWithMeals;

    DayMeal? nearest;
    Duration? smallestDiff;
    for (var day in days) {
      final diff = day.date.difference(todayDate).abs();
      if (smallestDiff == null || diff < smallestDiff) {
        smallestDiff = diff;
        nearest = day;
      }
    }
    return nearest;
  }

  void _publishMealCategories() {
    if (mealPlanResponse == null) return;

    final categoryMap = <String, MealCategoryItem>{};

    for (var day in mealPlanResponse!.data.mealPlan.days) {
      for (var meal in day.meals) {
        final id = meal.category.id.trim();
        final name = meal.category.dishCategory.trim();
        if (id.isEmpty || name.isEmpty) continue;

        if (!categoryMap.containsKey(id)) {
          categoryMap[id] = MealCategoryItem(
            id: id,
            name: name,
            isActive: meal.category.isActive,
          );
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(mealCategoryListProvider.notifier).state =
            categoryMap.values.toList();
      }
    });
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      case 'snacks':
        return Icons.cake_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          _buildLoadingState()
        else if (error != null)
          _isNullStringTypeError(error)
              ? _buildMealPlanContactAdminState()
              : _buildErrorState()
        else
          _buildMealPlanContent(),
      ],
    );
  }

  bool _isNullStringTypeError(String? message) {
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains("null is not a subtype of type 'string'") ||
        lower.contains('null is not a subtype of string') ||
        lower.contains("type 'null' is not a subtype of type 'string'") ||
        lower.contains("type 'null' is not a subtype of string");
  }

  void _showSubscriptionPlans() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => MembershipPopup(
        subscription: ref.read(walletProvider).subscription,
      ),
    );
  }

  Widget _buildMealPlanContactAdminState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.support_agent_rounded,
              size: 52, color: AppColors.primaryGreen),
          const SizedBox(height: AppSizes.spacing12),
          const Text(
            'Meal plan is not available',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          const Text(
            'Please contact admin to get your meal plan.\n'
                'Take a subscription plan to receive a call from our team.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.fontSize13,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _showSubscriptionPlans,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
              ),
              child: const Text(
                'Take Subscription Plan',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading your meal plan...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 64, color: Colors.red),
            ),
            const SizedBox(height: 24),
            Text(
              error ?? 'Something went wrong',
              style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: fetchMealPlan,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMealsForSelectedDate() {
    final day = selectedDayMeal;
    final dateLabel =
    day == null ? '' : DateFormat('EEE, d MMM').format(day.date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy_rounded,
              size: 48, color: AppColors.primaryGreen),
          const SizedBox(height: 12),
          const Text(
            'No meals planned',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 6),
          Text(
            dateLabel.isEmpty
                ? 'No meal categories are available for this day.'
                : 'No meal categories are available for $dateLabel.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMealPlanState() {
    final walletState = ref.watch(walletProvider);
    final hasSubscription = walletState.hasActiveSubscription;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.restaurant_menu_rounded,
              size: 52, color: AppColors.primaryGreen),
          const SizedBox(height: AppSizes.spacing12),
          if (!hasSubscription) ...[
            const Text(
              'No Active Subscription',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize16,
                fontWeight: AppTypography.semiBold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _showSubscriptionPlans,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                ),
                child: const Text(
                  'Take Subscription Plan',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
          ],
          const Text(
            "Don't worry, our nutritionist team will contact you soon",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              fontWeight: AppTypography.medium,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanContent() {
    if (selectedDayMeal == null) {
      return _buildNoMealPlanState();
    }

    final hasMeals = selectedDayMeal!.meals.isNotEmpty;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildDateSelector(),
          const SizedBox(height: 20),
          if (hasMeals) ...[
            // ── Custom tab bar — pure widget, zero ScrollPosition ──
            _buildCustomTabBar(),
            const SizedBox(height: 16),
            // ── Tab content — direct widget render, no AnimatedBuilder ──
            _buildCurrentTabContent(),
          ] else
            _buildNoMealsForSelectedDate(),
          _buildNutritionSummary(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkGreen, AppColors.primaryGreen],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Meal Plan',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Eat healthy, stay healthy',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: fetchMealPlan,
            icon: const Icon(Icons.refresh_rounded),
            color: Colors.white,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final days = mealPlanResponse!.data.mealPlan.days;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return SizedBox(
      height: 80,
      child: SingleChildScrollView(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(days.length, (index) {
            final day = days[index];
            final isSelected = selectedDayMeal?.date == day.date;
            final dayDate =
            DateTime(day.date.year, day.date.month, day.date.day);
            final isToday = dayDate.isAtSameMomentAs(todayDate);

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedDayMeal = day;
                  // Reset tab index when date changes
                  _selectedTabIndex = 0;
                  _animationController.reset();
                  _animationController.forward();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 60,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.darkGreen, AppColors.primaryGreen],
                  )
                      : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isToday
                        ? AppColors.darkGreen
                        : isSelected
                        ? Colors.transparent
                        : const Color(0xFFE5E7EB),
                    width: isToday ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE').format(day.date),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white70
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d').format(day.date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM').format(day.date),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white70
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── REPLACED: TabBar widget removed.
  //    The old TabBar used a TabController which internally attaches a
  //    ScrollController to the tab strip. That controller competes with
  //    the parent CustomScrollView on every vertical gesture, causing the
  //    snap-back on the dish cards on every single swipe.
  //    This custom tab bar is a plain Row of GestureDetectors — it has
  //    zero scroll context and zero gesture competition.
  Widget _buildCustomTabBar() {
    if (selectedDayMeal == null || selectedDayMeal!.meals.isEmpty) {
      return const SizedBox.shrink();
    }

    final meals = selectedDayMeal!.meals;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: List.generate(meals.length, (index) {
          final isSelected = _selectedTabIndex == index;
          final label = meals[index].category.dishCategory.trim().isNotEmpty
              ? meals[index].category.dishCategory
              : 'Meal';

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTabIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [AppColors.darkGreen, AppColors.primaryGreen],
                  )
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color:
                      AppColors.primaryGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── REPLACED: AnimatedBuilder(animation: _tabController!) removed.
  //    AnimatedBuilder on a TabController re-runs the builder on every
  //    animation frame of the controller's scroll animation, which was
  //    re-triggering layout and causing the parent scroll to fight for
  //    gesture ownership on each frame. Now we just read _selectedTabIndex
  //    directly — a plain synchronous index lookup, no listeners, no frames.
  Widget _buildCurrentTabContent() {
    if (selectedDayMeal == null || selectedDayMeal!.meals.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeIndex =
    _selectedTabIndex.clamp(0, selectedDayMeal!.meals.length - 1);
    return _buildMealCategoryContent(selectedDayMeal!.meals[safeIndex]);
  }

  Widget _buildMealCategoryContent(MealCategory mealCategory) {
    final title = mealCategory.category.dishCategory.trim().isNotEmpty
        ? mealCategory.category.dishCategory
        : 'Meal';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(title),
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      '${mealCategory.dishes.length} ${mealCategory.dishes.length == 1 ? 'dish' : 'dishes'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(
            mealCategory.dishes.length,
                (dishIndex) {
              final dish = mealCategory.dishes[dishIndex];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dishIndex > 0) const Divider(height: 24),
                  _buildDishItem(dish),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDishItem(Dish dish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dish.dishName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            if (dish.dishTypeLabel.isNotEmpty)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: dish.dishTypeLabel.toLowerCase() == 'veg'
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dish.dishTypeLabel.toLowerCase() == 'veg'
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dish.dishTypeLabel.toLowerCase() == 'veg'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dish.dishTypeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: dish.dishTypeLabel.toLowerCase() == 'veg'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        dish.remarks == ""
            ? const SizedBox.shrink()
            : Text(
          dish.remarks,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildNutrientChip(
              '${dish.nutritionalValue.kcal.toStringAsFixed(0)} kcal',
              const Color(0xFFeb3434),
            ),
            _buildNutrientChip(
              '${dish.nutritionalValue.protein.toStringAsFixed(1)}g Protein',
              const Color(0xFF0e9630),
            ),
            _buildNutrientChip(
              '${dish.nutritionalValue.fat.toStringAsFixed(1)}g Fats',
              const Color(0xFF0e9196),
            ),
            _buildNutrientChip(
              '${dish.nutritionalValue.carbs.toStringAsFixed(1)}g Carbohydrates',
              const Color(0xFF300e96),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutrientChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary() {
    double totalKcal = 0;
    double totalProtein = 0;
    double totalFat = 0;
    double totalCarbs = 0;

    for (var mealCategory in selectedDayMeal!.meals) {
      for (var dish in mealCategory.dishes) {
        totalKcal += dish.nutritionalValue.kcal;
        totalProtein += dish.nutritionalValue.protein;
        totalFat += dish.nutritionalValue.fat;
        totalCarbs += dish.nutritionalValue.carbs;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(mealPlanNutritionProvider.notifier).state = MealPlanNutrition(
          totalKcal: totalKcal,
          totalProtein: totalProtein,
          totalFat: totalFat,
          totalCarbs: totalCarbs,
        );
      }
    });

    return Container();
  }

  // ignore: unused_element
  Widget _buildSummaryItem(
      String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}