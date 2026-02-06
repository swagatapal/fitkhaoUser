import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';

/// Model for delivery slot
class DeliverySlot {
  final String slotId;
  final String slotName;
  final String timeRange;
  final IconData icon;
  final List<String> selectedMeals;

  DeliverySlot({
    required this.slotId,
    required this.slotName,
    required this.timeRange,
    required this.icon,
    this.selectedMeals = const [],
  });

  DeliverySlot copyWith({
    String? slotId,
    String? slotName,
    String? timeRange,
    IconData? icon,
    List<String>? selectedMeals,
  }) {
    return DeliverySlot(
      slotId: slotId ?? this.slotId,
      slotName: slotName ?? this.slotName,
      timeRange: timeRange ?? this.timeRange,
      icon: icon ?? this.icon,
      selectedMeals: selectedMeals ?? this.selectedMeals,
    );
  }
}

/// Provider for delivery slot selections
final deliverySlotProvider = StateProvider<List<DeliverySlot>>((ref) => [
      DeliverySlot(
        slotId: 'morning',
        slotName: 'Morning Slot',
        timeRange: '8:00 AM - 9:00 AM',
        icon: Icons.wb_sunny_rounded,
      ),
      DeliverySlot(
        slotId: 'afternoon',
        slotName: 'Afternoon Slot',
        timeRange: '12:00 PM - 1:00 PM',
        icon: Icons.wb_sunny_outlined,
      ),
      DeliverySlot(
        slotId: 'night',
        slotName: 'Night Slot',
        timeRange: '8:00 PM - 9:00 PM',
        icon: Icons.nightlight_round,
      ),
    ]);

/// Widget for delivery slot selection
class DeliverySlotSelector extends ConsumerStatefulWidget {
  const DeliverySlotSelector({super.key});

  @override
  ConsumerState<DeliverySlotSelector> createState() =>
      _DeliverySlotSelectorState();
}

class _DeliverySlotSelectorState extends ConsumerState<DeliverySlotSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final List<String> allMealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snacks', 'Smoothie'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Check if current time is between 6 PM and 11:59 PM
  bool _shouldShowSelector() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 18 && hour < 24; // 6 PM to 11:59 PM
  }

  /// Get available meals for a specific slot based on time
  List<String> _getAvailableMealsForSlot(String slotId) {
    switch (slotId) {
      case 'morning':
        // Morning: All 5 meal types
        return ['Breakfast', 'Lunch', 'Dinner', 'Snacks', 'Smoothie'];
      case 'afternoon':
        // Afternoon: 4 options (NO Breakfast)
        return ['Lunch', 'Dinner', 'Snacks', 'Smoothie'];
      case 'night':
        // Night: 3 options (NO Breakfast, NO Lunch)
        return ['Dinner', 'Snacks', 'Smoothie'];
      default:
        return [];
    }
  }

  /// Check if a meal type is already selected in ANY slot
  bool _isMealAlreadySelected(String meal) {
    final slots = ref.watch(deliverySlotProvider);
    for (var slot in slots) {
      if (slot.selectedMeals.contains(meal)) {
        return true;
      }
    }
    return false;
  }

  /// Get total selected meal count across all slots
  int _getTotalSelectedMeals() {
    final slots = ref.watch(deliverySlotProvider);
    return slots.fold(0, (sum, slot) => sum + slot.selectedMeals.length);
  }

  /// Toggle meal selection for a slot
  void _toggleMealSelection(String slotId, String meal) {
    final slots = ref.read(deliverySlotProvider);
    final slotIndex = slots.indexWhere((s) => s.slotId == slotId);

    if (slotIndex == -1) return;

    final slot = slots[slotIndex];
    final updatedMeals = List<String>.from(slot.selectedMeals);

    if (updatedMeals.contains(meal)) {
      // Remove meal from current slot
      updatedMeals.remove(meal);
    } else {
      // Check if this meal type is already selected in another slot
      if (_isMealAlreadySelected(meal)) {
        _showMealAlreadySelectedSnackbar(meal);
        return;
      }

      // Check if we can add more (max 5 meals total: 1 each of 5 types)
      final totalMeals = _getTotalSelectedMeals();
      if (totalMeals >= 5) {
        _showMaxSelectionSnackbar();
        return;
      }

      updatedMeals.add(meal);
    }

    // Update the slot
    final updatedSlots = List<DeliverySlot>.from(slots);
    updatedSlots[slotIndex] = slot.copyWith(selectedMeals: updatedMeals);
    ref.read(deliverySlotProvider.notifier).state = updatedSlots;
  }

  void _showMaxSelectionSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'All meal types selected! (1 of each: Breakfast, Lunch, Dinner, Snacks, Smoothie)',
          style: TextStyle(fontFamily: 'Lato'),
        ),
        backgroundColor: const Color(0xFFFF9800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
      ),
    );
  }

  void _showMealAlreadySelectedSnackbar(String meal) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$meal is already selected in another slot',
          style: const TextStyle(fontFamily: 'Lato'),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
      ),
    );
  }

  void _saveSlotSelections() {
    final totalMeals = _getTotalSelectedMeals();
    if (totalMeals == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please select at least one meal',
            style: TextStyle(fontFamily: 'Lato'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
        ),
      );
      return;
    }

    // TODO: Save selections to backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Delivery slots saved! ($totalMeals meals selected)',
          style: const TextStyle(fontFamily: 'Lato'),
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
      ),
    );
  }

  Color _getMealColor(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return const Color(0xFFFF9800); // Orange
      case 'lunch':
        return const Color(0xFF4CAF50); // Green
      case 'dinner':
        return const Color(0xFF2196F3); // Blue
      case 'snacks':
        return const Color(0xFFE91E63); // Pink
      case 'smoothie':
        return const Color(0xFF9C27B0); // Purple
      default:
        return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowSelector()) {
      return const SizedBox.shrink();
    }

    final slots = ref.watch(deliverySlotProvider);
    final totalSelected = _getTotalSelectedMeals();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A1B9A).withValues(alpha: 0.05),
                    const Color(0xFF8E24AA).withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radius12),
                border: Border.all(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(AppSizes.spacing16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppSizes.radius12),
                        topRight: Radius.circular(AppSizes.radius12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSizes.spacing8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppSizes.radius8),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: Colors.white,
                            size: AppSizes.icon24,
                          ),
                        ),
                        const SizedBox(width: AppSizes.spacing12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Delivery Slots',
                                style: TextStyle(
                                  fontSize: AppTypography.fontSize16,
                                  fontWeight: AppTypography.bold,
                                  color: Colors.white,
                                  fontFamily: 'Lato',
                                ),
                              ),
                              SizedBox(height: AppSizes.spacing2),
                              Text(
                                'Pick 1 of each meal type for tomorrow',
                                style: TextStyle(
                                  fontSize: AppTypography.fontSize12,
                                  fontWeight: AppTypography.regular,
                                  color: Colors.white70,
                                  fontFamily: 'Lato',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spacing10,
                            vertical: AppSizes.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: totalSelected >= 5
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppSizes.radius20),
                          ),
                          child: Text(
                            '$totalSelected/5',
                            style: TextStyle(
                              fontSize: AppTypography.fontSize14,
                              fontWeight: AppTypography.bold,
                              color: totalSelected >= 5
                                  ? const Color(0xFF6A1B9A)
                                  : Colors.white,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Slot Cards
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.spacing16),
                    child: Column(
                      children: [
                        ...slots.asMap().entries.map((entry) {
                          final index = entry.key;
                          final slot = entry.value;
                          return Column(
                            children: [
                              if (index > 0)
                                const SizedBox(height: AppSizes.spacing12),
                              _buildSlotCard(slot),
                            ],
                          );
                        }).toList(),

                        const SizedBox(height: AppSizes.spacing16),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: AppSizes.buttonHeight,
                          child: ElevatedButton(
                            onPressed: _saveSlotSelections,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6A1B9A),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radius8),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                  size: AppSizes.icon20,
                                ),
                                const SizedBox(width: AppSizes.spacing8),
                                Text(
                                  totalSelected > 0
                                      ? 'Confirm $totalSelected Slot${totalSelected > 1 ? 's' : ''}'
                                      : 'Select Meals',
                                  style: const TextStyle(
                                    fontSize: AppTypography.fontSize16,
                                    fontWeight: AppTypography.semiBold,
                                    color: Colors.white,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlotCard(DeliverySlot slot) {
    final hasSelections = slot.selectedMeals.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: hasSelections
              ? const Color(0xFF6A1B9A)
              : Colors.grey.withValues(alpha: 0.2),
          width: hasSelections ? 2 : 1,
        ),
        boxShadow: hasSelections
            ? [
                BoxShadow(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot Header
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            decoration: BoxDecoration(
              color: hasSelections
                  ? const Color(0xFF6A1B9A).withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSizes.radius8),
                topRight: Radius.circular(AppSizes.radius8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing8),
                  decoration: BoxDecoration(
                    color: hasSelections
                        ? const Color(0xFF6A1B9A)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: Icon(
                    slot.icon,
                    color: hasSelections ? Colors.white : Colors.grey.shade600,
                    size: AppSizes.icon20,
                  ),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.slotName,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.semiBold,
                          color: hasSelections
                              ? const Color(0xFF6A1B9A)
                              : AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing2),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: AppSizes.icon12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSizes.spacing4),
                          Text(
                            slot.timeRange,
                            style: const TextStyle(
                              fontSize: AppTypography.fontSize12,
                              fontWeight: AppTypography.regular,
                              color: AppColors.textSecondary,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasSelections)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing8,
                      vertical: AppSizes.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A),
                      borderRadius: BorderRadius.circular(AppSizes.radius12),
                    ),
                    child: Text(
                      '${slot.selectedMeals.length} meal${slot.selectedMeals.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.bold,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Meal Selection Chips
          Padding(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            child: Wrap(
              spacing: AppSizes.spacing8,
              runSpacing: AppSizes.spacing8,
              children: _getAvailableMealsForSlot(slot.slotId).map((meal) {
                final isSelected = slot.selectedMeals.contains(meal);
                final isAlreadySelected = _isMealAlreadySelected(meal);
                final isDisabled = isAlreadySelected && !isSelected;
                final mealColor = _getMealColor(meal);

                return GestureDetector(
                  onTap: isDisabled ? null : () => _toggleMealSelection(slot.slotId, meal),
                  child: Opacity(
                    opacity: isDisabled ? 0.4 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacing12,
                        vertical: AppSizes.spacing8,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  mealColor,
                                  mealColor.withValues(alpha: 0.8),
                                ],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : isDisabled
                                ? Colors.grey.withValues(alpha: 0.2)
                                : mealColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radius20),
                        border: Border.all(
                          color: isSelected
                              ? mealColor
                              : isDisabled
                                  ? Colors.grey.withValues(alpha: 0.4)
                                  : mealColor.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(right: AppSizes.spacing6),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: AppSizes.icon16,
                              ),
                            ),
                          Text(
                            meal,
                            style: TextStyle(
                              fontSize: AppTypography.fontSize13,
                              fontWeight: isSelected
                                  ? AppTypography.bold
                                  : AppTypography.medium,
                              color: isSelected ? Colors.white : mealColor,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
