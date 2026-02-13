import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/delivery_slot_model.dart';
import '../../providers/delivery_slot_provider.dart';

/// Local model for tracking meal selections per slot
class SlotMealSelection {
  final String slotId;
  final String slotName;
  final String timeRange;
  final String slotType;
  /// Selected category IDs (maps to MealCategoryItem.id)
  final List<String> selectedCategoryIds;

  SlotMealSelection({
    required this.slotId,
    required this.slotName,
    required this.timeRange,
    required this.slotType,
    this.selectedCategoryIds = const [],
  });

  SlotMealSelection copyWith({List<String>? selectedCategoryIds}) {
    return SlotMealSelection(
      slotId: slotId,
      slotName: slotName,
      timeRange: timeRange,
      slotType: slotType,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
    );
  }
}

/// Provider for meal selections (local state per slot)
final slotMealSelectionProvider =
    StateProvider<List<SlotMealSelection>>((ref) => []);

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
  bool _slotsInitialized = false;
  bool _isSubmitting = false;

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

    // Fetch delivery slots from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deliverySlotApiProvider.notifier).loadDeliverySlots();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Get icon for slot type
  IconData _getSlotIcon(String slotType) {
    switch (slotType) {
      case 'morning':
        return Icons.wb_sunny_rounded;
      case 'afternoon':
        return Icons.wb_sunny_outlined;
      case 'night':
        return Icons.nightlight_round;
      default:
        return Icons.schedule;
    }
  }

  /// Initialize meal selection state from API slots and previous selections
  void _initializeMealSelections(DeliverySlotState slotState) {
    if (_slotsInitialized) return;
    _slotsInitialized = true;

    final apiSlots = slotState.slots;
    final previousSelections = slotState.previousSelection;

    final selections = apiSlots.map((slot) {
      // Check if this slot has previous selections
      final previous = previousSelections
          .where((p) => p.slotId == slot.id)
          .toList();
      final categoryIds = previous.isNotEmpty
          ? List<String>.from(previous.first.categoryIds)
          : <String>[];

      return SlotMealSelection(
        slotId: slot.id,
        slotName: slot.slotName.isNotEmpty ? slot.slotName : _getSlotNameFromTime(slot.slotStartTime),
        timeRange: slot.timeRange,
        slotType: slot.slotType,
        selectedCategoryIds: categoryIds,
      );
    }).toList();

    // Defer provider update to avoid modifying state during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(slotMealSelectionProvider.notifier).state = selections;
        _animationController.forward();
      }
    });
  }

  /// Generate slot name from start time if API doesn't provide slotName
  String _getSlotNameFromTime(String startTime) {
    final hour = _parseHour(startTime);
    if (hour >= 5 && hour < 11) return 'Morning Slot';
    if (hour >= 11 && hour < 17) return 'Afternoon Slot';
    return 'Night Slot';
  }

  /// Parse hour from time string like "8:00 AM" or "12:00 PM"
  int _parseHour(String time) {
    try {
      final parts = time.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final period = parts.length > 1 ? parts[1].toUpperCase() : '';
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour;
    } catch (_) {
      return 0;
    }
  }

  /// Get available meal categories for a slot from the API response
  List<AvailableMealCategory> _getAvailableCategoriesForSlot(String slotType, DeliverySlotState slotState) {
    final allCategories = slotState.availableMeals;
    if (allCategories.isEmpty) return [];

    switch (slotType) {
      case 'morning':
        return allCategories;
      case 'afternoon':
        return allCategories
            .where((c) => c.categoryName.toLowerCase() != 'breakfast')
            .toList();
      case 'night':
        return allCategories
            .where((c) =>
                c.categoryName.toLowerCase() != 'breakfast' &&
                c.categoryName.toLowerCase() != 'lunch')
            .toList();
      default:
        return [];
    }
  }

  /// Check if a category is already selected in ANY slot
  bool _isCategoryAlreadySelected(String categoryId) {
    final selections = ref.read(slotMealSelectionProvider);
    for (var sel in selections) {
      if (sel.selectedCategoryIds.contains(categoryId)) {
        return true;
      }
    }
    return false;
  }

  /// Get total selected meal count across all slots
  int _getTotalSelectedMeals() {
    final selections = ref.watch(slotMealSelectionProvider);
    return selections.fold(
        0, (sum, sel) => sum + sel.selectedCategoryIds.length);
  }

  /// Toggle meal category selection for a slot
  void _toggleMealSelection(String slotId, AvailableMealCategory category, DeliverySlotState slotState) {
    if (slotState.alreadyConfirmed) return;
    final selections = ref.read(slotMealSelectionProvider);
    final index = selections.indexWhere((s) => s.slotId == slotId);

    if (index == -1) return;

    final sel = selections[index];
    final updatedIds = List<String>.from(sel.selectedCategoryIds);

    if (updatedIds.contains(category.categoryId)) {
      updatedIds.remove(category.categoryId);
    } else {
      // Check if this category is already selected in another slot
      if (_isCategoryAlreadySelected(category.categoryId)) {
        _showMealAlreadySelectedSnackbar(category.categoryName);
        return;
      }

      // Check max total
      final totalMeals = _getTotalSelectedMeals();
      if (totalMeals >= slotState.availableMeals.length) {
        _showMaxSelectionSnackbar(slotState);
        return;
      }

      updatedIds.add(category.categoryId);
    }

    final updatedSelections = List<SlotMealSelection>.from(selections);
    updatedSelections[index] = sel.copyWith(selectedCategoryIds: updatedIds);
    ref.read(slotMealSelectionProvider.notifier).state = updatedSelections;
  }

  void _showMaxSelectionSnackbar(DeliverySlotState slotState) {
    final names = slotState.availableMeals.map((c) => c.categoryName).join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'All meal types selected! ($names)',
          style: const TextStyle(fontFamily: 'Lato'),
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

  /// Get delivery date (tomorrow) formatted as yyyy-MM-dd
  String _getDeliveryDate() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
  }

  /// Submit delivery slot selections to API
  Future<void> _saveSlotSelections() async {
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

    setState(() => _isSubmitting = true);

    try {
      final selections = ref.read(slotMealSelectionProvider);
      final authState = ref.read(authProvider);

      // Build slots list (only slots with selections)
      final confirmSlots = selections
          .where((sel) => sel.selectedCategoryIds.isNotEmpty)
          .map((sel) => ConfirmSlotItem(
                slotId: sel.slotId,
                categoryIds: sel.selectedCategoryIds,
              ))
          .toList();

      // Build request
      final request = ConfirmDeliverySlotRequest(
        deliveryDate: _getDeliveryDate(),
        slots: confirmSlots,
        deliveryAddress: ConfirmDeliveryAddress(
          buildingName: authState.buildingNameNumber,
          street: authState.street,
          pincode: authState.pincode,
          contactNumber: authState.phoneNumber,
        ),
        paymentMethod: 'wallet',
      );

      // Call API
      final repo = ref.read(deliverySlotRepositoryProvider);
      final response = await repo.confirmDeliverySlots(request: request);

      if (!mounted) return;

      if (response.success) {
        // Reload slots from API to get updated state (alreadyConfirmed = true)
        await ref.read(deliverySlotApiProvider.notifier).refresh();
        if (!mounted) return;

        // Reset initialization flag so selections rebuild with API data
        _slotsInitialized = false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message.isNotEmpty
                  ? response.message
                  : 'Delivery slots confirmed! ($totalMeals meals selected)',
              style: const TextStyle(fontFamily: 'Lato'),
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message.isNotEmpty
                  ? response.message
                  : 'Failed to confirm delivery slots',
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            style: const TextStyle(fontFamily: 'Lato'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
    final slotState = ref.watch(deliverySlotApiProvider);
    final mealSelections = ref.watch(slotMealSelectionProvider);
    final totalSelected = _getTotalSelectedMeals();
    final totalCategories = slotState.availableMeals.length;
    final isConfirmed = slotState.alreadyConfirmed;

    // Don't show if not within selection window (from API)
    if (!slotState.isLoading && !slotState.isWithinWindow && slotState.slots.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show loading state
    if (slotState.isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
        padding: const EdgeInsets.all(AppSizes.spacing24),
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
        child: const Center(
          child: Column(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF6A1B9A)),
                ),
              ),
              SizedBox(height: AppSizes.spacing12),
              Text(
                'Loading delivery slots...',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.medium,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (slotState.error != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
        padding: const EdgeInsets.all(AppSizes.spacing16),
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border: Border.all(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFD32F2F), size: AppSizes.icon20),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Text(
                slotState.error!,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize13,
                  color: Color(0xFFD32F2F),
                  fontFamily: 'Lato',
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(deliverySlotApiProvider.notifier).refresh();
              },
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Color(0xFF6A1B9A),
                  fontWeight: AppTypography.semiBold,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ),
      );
    }

    // No slots or no meal categories yet
    if (slotState.slots.isEmpty || slotState.availableMeals.isEmpty) {
      return const SizedBox.shrink();
    }

    // Initialize meal selections from API data (once)
    _initializeMealSelections(slotState);

    // Don't render until selections are initialized
    if (mealSelections.isEmpty) {
      return const SizedBox.shrink();
    }

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
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
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
                            borderRadius:
                                BorderRadius.circular(AppSizes.radius8),
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
                            color: totalSelected >= totalCategories
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radius20),
                          ),
                          child: Text(
                            '$totalSelected/$totalCategories',
                            style: TextStyle(
                              fontSize: AppTypography.fontSize14,
                              fontWeight: AppTypography.bold,
                              color: totalSelected >= totalCategories
                                  ? const Color(0xFF6A1B9A)
                                  : Colors.white,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Confirmed banner
                  if (isConfirmed)
                    Container(
                      margin: const EdgeInsets.fromLTRB(
                        AppSizes.spacing16,
                        AppSizes.spacing16,
                        AppSizes.spacing16,
                        0,
                      ),
                      padding: const EdgeInsets.all(AppSizes.spacing12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                        border: Border.all(
                          color: AppColors.primaryGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primaryGreen,
                            size: AppSizes.icon20,
                          ),
                          const SizedBox(width: AppSizes.spacing10),
                          const Expanded(
                            child: Text(
                              'You have already confirmed your delivery slots for tomorrow. You can update once per day.',
                              style: TextStyle(
                                fontSize: AppTypography.fontSize13,
                                fontWeight: AppTypography.medium,
                                color: AppColors.textPrimary,
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
                        ...mealSelections.asMap().entries.map((entry) {
                          final index = entry.key;
                          final sel = entry.value;
                          return Column(
                            children: [
                              if (index > 0)
                                const SizedBox(height: AppSizes.spacing12),
                              _buildSlotCard(sel, slotState),
                            ],
                          );
                        }),

                        const SizedBox(height: AppSizes.spacing16),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: AppSizes.buttonHeight,
                          child: ElevatedButton(
                            onPressed: isConfirmed || _isSubmitting
                                ? null
                                : _saveSlotSelections,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isConfirmed
                                  ? Colors.grey
                                  : const Color(0xFF6A1B9A),
                              disabledBackgroundColor: isConfirmed
                                  ? Colors.grey.withValues(alpha: 0.5)
                                  : const Color(0xFF6A1B9A).withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radius8),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isConfirmed
                                            ? Icons.lock_rounded
                                            : Icons.check_circle_outline,
                                        color: Colors.white,
                                        size: AppSizes.icon20,
                                      ),
                                      const SizedBox(width: AppSizes.spacing8),
                                      Text(
                                        isConfirmed
                                            ? 'Already Confirmed'
                                            : totalSelected > 0
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

  Widget _buildSlotCard(SlotMealSelection sel, DeliverySlotState slotState) {
    final hasSelections = sel.selectedCategoryIds.isNotEmpty;
    final availableCategories = _getAvailableCategoriesForSlot(sel.slotType, slotState);
    final isConfirmed = slotState.alreadyConfirmed;

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
                    _getSlotIcon(sel.slotType),
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
                        sel.slotName,
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
                            sel.timeRange,
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
                      '${sel.selectedCategoryIds.length} meal${sel.selectedCategoryIds.length > 1 ? 's' : ''}',
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
              children: availableCategories.map((category) {
                final isSelected =
                    sel.selectedCategoryIds.contains(category.categoryId);
                final isAlreadySelected =
                    _isCategoryAlreadySelected(category.categoryId);
                final isDisabled = isConfirmed || (isAlreadySelected && !isSelected);
                final mealColor = _getMealColor(category.categoryName);

                return GestureDetector(
                  onTap: isDisabled
                      ? null
                      : () => _toggleMealSelection(sel.slotId, category, slotState),
                  child: Opacity(
                    opacity: isDisabled && !isSelected ? 0.4 : 1.0,
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
                        borderRadius:
                            BorderRadius.circular(AppSizes.radius20),
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
                              padding:
                                  EdgeInsets.only(right: AppSizes.spacing6),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: AppSizes.icon16,
                              ),
                            ),
                          Text(
                            category.categoryName,
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
