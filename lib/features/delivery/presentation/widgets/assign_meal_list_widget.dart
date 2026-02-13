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
      success: json['success'],
      message: json['message'],
      data: MealPlanData.fromJson(json['data']),
    );
  }
}

class MealPlanData {
  final MealPlan mealPlan;

  MealPlanData({required this.mealPlan});

  factory MealPlanData.fromJson(Map<String, dynamic> json) {
    return MealPlanData(
      mealPlan: MealPlan.fromJson(json['mealPlan']),
    );
  }
}

class MealPlan {
  final String id;
  final List<DayMeal> days;

  MealPlan({required this.id, required this.days});

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: json['_id'],
      days: (json['days'] as List).map((day) => DayMeal.fromJson(day)).toList(),
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
      date: DateTime.parse(json['date']),
      isDeleted: json['isDeleted'],
      meals: (json['meals'] as List)
          .map((meal) => MealCategory.fromJson(meal))
          .toList(),
    );
  }
}

class MealCategory {
  final Category category;
  final List<Dish> dishes;

  MealCategory({required this.category, required this.dishes});

  factory MealCategory.fromJson(Map<String, dynamic> json) {
    return MealCategory(
      category: Category.fromJson(json['category']),
      dishes:
          (json['dishes'] as List).map((dish) => Dish.fromJson(dish)).toList(),
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
      id: json['_id'],
      dishCategory: json['dishCategory'],
      isActive: json['isActive'],
    );
  }
}

class Dish {
  final String id;
  final String dishCode;
  final String dishName;
  final String dishType;
  final NutritionalValue nutritionalValue;
  final double costPrice;
  final double marketPrice;
  final bool isActive;

  Dish({
    required this.id,
    required this.dishCode,
    required this.dishName,
    required this.dishType,
    required this.nutritionalValue,
    required this.costPrice,
    required this.marketPrice,
    required this.isActive,
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: json['_id'],
      dishCode: json['dishCode'],
      dishName: json['dishName'],
      dishType: json['dishType'],
      nutritionalValue: NutritionalValue.fromJson(json['nutritionalValue']),
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      marketPrice: (json['marketPrice'] ?? 0).toDouble(),
      isActive: json['isActive'],
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
      kcal: (json['kcal'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
    );
  }
}

// Main Widget - NO SCAFFOLD
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
    with TickerProviderStateMixin {
  MealPlanResponse? mealPlanResponse;
  DayMeal? selectedDayMeal;
  bool isLoading = true;
  String? error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  TabController? _tabController;
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
    _tabController?.dispose();
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

        // Find nearest date to today
        selectedDayMeal = _findNearestDayMeal();

        // Initialize tab controller
        if (selectedDayMeal != null && selectedDayMeal!.meals.isNotEmpty) {
          _tabController?.dispose();
          _tabController = TabController(
            length: selectedDayMeal!.meals.length,
            vsync: this,
          );
        }

        // Publish meal categories to provider for DeliverySlotSelector
        _publishMealCategories();

        // Mark meal plan as available
        ref.read(mealPlanAvailableProvider.notifier).state = true;

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

  /// Scroll the date selector so that the selected date is visible
  void _scrollToSelectedDate() {
    if (mealPlanResponse == null || selectedDayMeal == null) return;

    final days = mealPlanResponse!.data.mealPlan.days;
    final selectedIndex =
        days.indexWhere((d) => d.date == selectedDayMeal!.date);
    if (selectedIndex < 0) return;

    // Each date item is 60 wide + 12 margin = 72 per item
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

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // First, try to find exact match
    for (var day in mealPlanResponse!.data.mealPlan.days) {
      final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
      if (dayDate.isAtSameMomentAs(todayDate)) {
        return day;
      }
    }

    // If no exact match, find nearest date
    DayMeal? nearest;
    Duration? smallestDiff;

    for (var day in mealPlanResponse!.data.mealPlan.days) {
      final diff = day.date.difference(todayDate).abs();
      if (smallestDiff == null || diff < smallestDiff) {
        smallestDiff = diff;
        nearest = day;
      }
    }

    return nearest;
  }

  /// Extract unique meal categories from the meal plan and publish to provider
  void _publishMealCategories() {
    if (mealPlanResponse == null) return;

    final categoryMap = <String, MealCategoryItem>{};

    for (var day in mealPlanResponse!.data.mealPlan.days) {
      for (var meal in day.meals) {
        if (!categoryMap.containsKey(meal.category.id)) {
          categoryMap[meal.category.id] = MealCategoryItem(
            id: meal.category.id,
            name: meal.category.dishCategory,
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

  // ignore: unused_element
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'breakfast':
        return AppColors.primaryGreen;
      case 'lunch':
        return AppColors.primaryGreen;
      case 'dinner':
        return AppColors.primaryGreen;
      case 'snacks':
        return AppColors.primaryGreen;
      default:
        return AppColors.primaryGreen;
    }
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
          const Icon(
            Icons.support_agent_rounded,
            size: 52,
            color: AppColors.primaryGreen,
          ),
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
              child: const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              error ?? 'Something went wrong',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
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

  Widget _buildMealPlanContent() {
    if (selectedDayMeal == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No meal plan available'),
        ),
      );
    }

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
          _buildTabBar(),
          const SizedBox(height: 16),
          _buildTabBarView(),
          // const SizedBox(height: 16),
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
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: Colors.white,
              size: 24,
            ),
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
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Eat healthy, stay healthy',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
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
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = selectedDayMeal?.date == day.date;
          final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
          final isToday = dayDate.isAtSameMomentAs(todayDate);

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedDayMeal = day;
                _tabController?.dispose();
                _tabController = TabController(
                  length: day.meals.length,
                  vsync: this,
                );
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
                      color:
                          isSelected ? Colors.white70 : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(day.date),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM').format(day.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          isSelected ? Colors.white70 : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    if (_tabController == null || selectedDayMeal == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.darkGreen, AppColors.primaryGreen],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        tabs: selectedDayMeal!.meals.map((mealCategory) {
          return Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon(icon, size: 18),
                // const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    mealCategory.category.dishCategory,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBarView() {
    if (_tabController == null || selectedDayMeal == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _tabController!,
      builder: (context, child) {
        final index = _tabController!.index;
        return _buildMealCategoryContent(selectedDayMeal!.meals[index]);
      },
    );
  }

  Widget _buildMealCategoryContent(MealCategory mealCategory) {
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
                  _getCategoryIcon(mealCategory.category.dishCategory),
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
                      mealCategory.category.dishCategory,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      '${mealCategory.dishes.length} ${mealCategory.dishes.length == 1 ? 'dish' : 'dishes'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: dish.dishType.toLowerCase() == 'veg'
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: dish.dishType.toLowerCase() == 'veg'
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
                      color: dish.dishType.toLowerCase() == 'veg'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dish.dishType,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: dish.dishType.toLowerCase() == 'veg'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildNutrientChip(
              //Icons.local_fire_department_rounded,
              '${dish.nutritionalValue.kcal.toStringAsFixed(0)} kcal',
              const Color(0xFFeb3434),
            ),
            _buildNutrientChip(
              //Icons.fitness_center_rounded,
              '${dish.nutritionalValue.protein.toStringAsFixed(1)}g Protein',
              const Color(0xFF0e9630),
            ),
            _buildNutrientChip(
              //Icons.opacity_rounded,
              '${dish.nutritionalValue.fat.toStringAsFixed(1)}g Fats',
              const Color(0xFF0e9196),
            ),
            _buildNutrientChip(
              //Icons.grain_rounded,
              '${dish.nutritionalValue.carbs.toStringAsFixed(1)}g Carbohydrates',
              const Color(0xFF300e96),
            ),
          ],
        ),
        // if (dish.marketPrice > 0) ...[
        //   const SizedBox(height: 12),
        //   Row(
        //     children: [
        //       Text(
        //         '₹${dish.marketPrice.toStringAsFixed(0)}',
        //         style: TextStyle(
        //           fontSize: 18,
        //           fontWeight: FontWeight.bold,
        //           color: AppColors.primaryGreen,
        //         ),
        //       ),
        //       if (dish.costPrice > 0) ...[
        //         const SizedBox(width: 8),
        //         Text(
        //           '₹${dish.costPrice.toStringAsFixed(0)}',
        //           style: const TextStyle(
        //             fontSize: 14,
        //             decoration: TextDecoration.lineThrough,
        //             color: Color(0xFF9CA3AF),
        //           ),
        //         ),
        //       ],
        //     ],
        //   ),
        // ],
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
    // Calculate total nutrition for the selected day
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

    // Update the provider with calculated nutrition values
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

    return Container(
        // padding: const EdgeInsets.all(16),
        // decoration: BoxDecoration(
        //   gradient: LinearGradient(
        //     begin: Alignment.topLeft,
        //     end: Alignment.bottomRight,
        //     colors: [
        //       AppColors.darkGreen,
        //       AppColors.primaryGreen,
        //     ],
        //   ),
        //   borderRadius: BorderRadius.circular(8),
        //   boxShadow: [
        //     BoxShadow(
        //       color: AppColors.primaryGreen.withOpacity(0.3),
        //       blurRadius: 20,
        //       offset: const Offset(0, 10),
        //     ),
        //   ],
        // ),
        // child: Column(
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     const Row(
        //       children: [
        //         Icon(
        //           Icons.assessment_rounded,
        //           color: Colors.white,
        //           size: 24,
        //         ),
        //         SizedBox(width: 12),
        //         Text(
        //           'Daily Nutrition Summary',
        //           style: TextStyle(
        //             fontSize: 18,
        //             fontWeight: FontWeight.bold,
        //             color: Colors.white,
        //           ),
        //         ),
        //       ],
        //     ),
        //     const SizedBox(height: 20),
        //     Row(
        //       children: [
        //         Expanded(
        //           child: _buildSummaryItem(
        //             'Calories',
        //             totalKcal.toStringAsFixed(0),
        //             'kcal',
        //             Icons.local_fire_department_rounded,
        //           ),
        //         ),
        //         Expanded(
        //           child: _buildSummaryItem(
        //             'Protein',
        //             totalProtein.toStringAsFixed(1),
        //             'g',
        //             Icons.fitness_center_rounded,
        //           ),
        //         ),
        //       ],
        //     ),
        //     const SizedBox(height: 12),
        //     Row(
        //       children: [
        //         Expanded(
        //           child: _buildSummaryItem(
        //             'Fat',
        //             totalFat.toStringAsFixed(1),
        //             'g',
        //             Icons.opacity_rounded,
        //           ),
        //         ),
        //         Expanded(
        //           child: _buildSummaryItem(
        //             'Carbs',
        //             totalCarbs.toStringAsFixed(1),
        //             'g',
        //             Icons.grain_rounded,
        //           ),
        //         ),
        //       ],
        //     ),
        //   ],
        // ),
        );
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
              Icon(
                icon,
                color: Colors.white70,
                size: 16,
              ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
