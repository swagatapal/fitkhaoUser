import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../delivery/models/delivery_slot_model.dart';
import '../../../delivery/providers/delivery_slot_provider.dart';

/// Map from slotId → selected categoryIds chosen by the user
typedef SlotSelection = Map<String, List<String>>;

class DeliverySlotWidget extends ConsumerStatefulWidget {
  const DeliverySlotWidget({super.key});

  @override
  ConsumerState<DeliverySlotWidget> createState() => _DeliverySlotWidgetState();
}

class _DeliverySlotWidgetState extends ConsumerState<DeliverySlotWidget> {
  /// Current user selections: slotId → [categoryId, ...]
  SlotSelection _selection = {};
  bool _initialised = false;
  bool _isSubmitting = false;

  /// Pre-fill selection from previous confirmed data
  void _initialiseSelection(DeliverySlotState state) {
    if (_initialised) return;
    _initialised = true;

    if (state.previousSelection.isNotEmpty) {
      _selection = {
        for (final p in state.previousSelection)
          if (p.slotId.isNotEmpty) p.slotId: List<String>.from(p.categoryIds),
      };
    }
  }

  void _toggleCategory(String slotId, String categoryId) {
    setState(() {
      final current = List<String>.from(_selection[slotId] ?? []);
      if (current.contains(categoryId)) {
        current.remove(categoryId);
      } else {
        current.add(categoryId);
      }
      if (current.isEmpty) {
        _selection.remove(slotId);
      } else {
        _selection[slotId] = current;
      }
    });
  }

  void _selectSlotForAllMeals(String slotId, List<AvailableMealCategory> meals) {
    setState(() {
      // Clear other slots
      _selection.clear();
      _selection[slotId] = meals.map((m) => m.categoryId).toList();
    });
  }

  bool _isCategorySelected(String slotId, String categoryId) =>
      (_selection[slotId] ?? []).contains(categoryId);

  bool _isSlotSelected(String slotId) =>
      (_selection[slotId] ?? []).isNotEmpty;

  /// Total assigned meals count across all slot selections
  int get _totalSelectedCount =>
      _selection.values.fold(0, (sum, ids) => sum + ids.length);

  bool get _hasValidSelection => _totalSelectedCount > 0;

  Future<void> _submit(DeliverySlotState state) async {
    if (!_hasValidSelection || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    // Build confirm items from current selection
    final items = _selection.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => ConfirmSlotItem(slotId: e.key, categoryIds: e.value))
        .toList();

    debugPrint('[DeliverySlotWidget] Submitting ${items.length} slot(s):');
    for (final item in items) {
      debugPrint('  slotId=${item.slotId} categories=${item.categoryIds}');
    }

    // TODO: Wire to confirm API when provided
    await Future.delayed(const Duration(milliseconds: 400));

    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery slot confirmed!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliverySlotApiProvider);

    if (state.isLoading) return _buildSkeleton();
    if (state.error != null) return _buildError(state.error!);
    if (state.slots.isEmpty) return const SizedBox.shrink();

    _initialiseSelection(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(state),
        const SizedBox(height: AppSizes.spacing12),
        if (state.alreadyConfirmed)
          _buildAlreadyConfirmedBanner(state)
        else if (!state.isWithinWindow)
          _buildOutOfWindowBanner(state)
        else ...[
          if (state.previousSelection.isNotEmpty)
            _buildPreviousSelectionHint(state),
          _buildSlotCards(state),
          const SizedBox(height: AppSizes.spacing16),
          _buildSubmitButton(state),
        ],
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(DeliverySlotState state) {
    final deliveryDate = _formatDeliveryDate(state.deliveryDate);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery Slot',
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              if (deliveryDate.isNotEmpty)
                Text(
                  'For $deliveryDate',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
            ],
          ),
        ),
        // Selection summary badge
        if (_hasValidSelection)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing10,
              vertical: AppSizes.spacing4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(AppSizes.radius20),
            ),
            child: Text(
              '$_totalSelectedCount meal${_totalSelectedCount > 1 ? 's' : ''} selected',
              style: const TextStyle(
                fontSize: AppTypography.fontSize10,
                fontWeight: AppTypography.semiBold,
                color: Colors.white,
                fontFamily: 'Lato',
              ),
            ),
          ),
      ],
    );
  }

  // ── Banners ──────────────────────────────────────────────────────────────

  Widget _buildAlreadyConfirmedBanner(DeliverySlotState state) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: AppSizes.spacing8),
              const Expanded(
                child: Text(
                  'Slot already confirmed for tomorrow',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.primaryGreen,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
          if (state.previousSelection.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacing12),
            ...state.previousSelection.map((sel) =>
                _buildConfirmedSlotRow(sel, state)),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmedSlotRow(
      PreviousSlotSelection sel, DeliverySlotState state) {
    final slot = state.slots
        .cast<DeliverySlotApiModel?>()
        .firstWhere((s) => s?.id == sel.slotId, orElse: () => null);
    final mealNames = sel.categoryIds
        .map((id) => state.availableMeals
            .cast<AvailableMealCategory?>()
            .firstWhere((m) => m?.categoryId == id, orElse: () => null)
            ?.categoryName ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot != null
                      ? '${slot.slotName}  (${slot.timeRange})'
                      : sel.slotId,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                if (mealNames.isNotEmpty)
                  Text(
                    mealNames,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfWindowBanner(DeliverySlotState state) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.access_time, color: Color(0xFFF57F17), size: 20),
          const SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Slot selection window is closed',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: Color(0xFFF57F17),
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You can select slots between '
                  '${state.selectionWindow.start} – ${state.selectionWindow.end}.',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
                if (state.previousSelection.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.spacing8),
                  ...state.previousSelection.map((sel) =>
                      _buildConfirmedSlotRow(sel, state)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousSelectionHint(DeliverySlotState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing12,
          vertical: AppSizes.spacing8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8FF),
          borderRadius: BorderRadius.circular(AppSizes.radius4),
          border: Border.all(color: const Color(0xFFBBDEFB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: Color(0xFF1565C0)),
            const SizedBox(width: AppSizes.spacing8),
            const Expanded(
              child: Text(
                'Previous selection pre-filled. You can update it.',
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: Color(0xFF1565C0),
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Slot Cards ───────────────────────────────────────────────────────────

  Widget _buildSlotCards(DeliverySlotState state) {
    return Column(
      children: state.slots
          .where((s) => s.isActive)
          .map((slot) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spacing10),
                child: _buildSlotCard(slot, state.availableMeals),
              ))
          .toList(),
    );
  }

  Widget _buildSlotCard(
      DeliverySlotApiModel slot, List<AvailableMealCategory> meals) {
    final selected = _isSlotSelected(slot.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: selected
              ? AppColors.primaryGreen
              : AppColors.borderColor,
          width: selected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? AppColors.primaryGreen.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: selected ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot header row
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacing12,
              AppSizes.spacing12,
              AppSizes.spacing12,
              AppSizes.spacing8,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryGreen.withValues(alpha: 0.1)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  child: Icon(
                    _slotIcon(slot.slotType),
                    size: 18,
                    color: selected
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSizes.spacing10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.slotName,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.semiBold,
                          color: selected
                              ? AppColors.primaryGreen
                              : AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      Text(
                        slot.timeRange,
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
                // "Select all" quick-pick button
                if (meals.isNotEmpty)
                  GestureDetector(
                    onTap: () => _selectSlotForAllMeals(slot.id, meals),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacing8,
                        vertical: AppSizes.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryGreen
                            : AppColors.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                      ),
                      child: Text(
                        selected ? 'Selected' : 'Select all',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize10,
                          fontWeight: AppTypography.semiBold,
                          color: selected
                              ? Colors.white
                              : AppColors.primaryGreen,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1),
          // Meal category chips
          Padding(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            child: meals.isEmpty
                ? const Text(
                    'No meals available for this slot',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  )
                : Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: meals
                        .map((meal) => _buildMealChip(slot.id, meal))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealChip(String slotId, AvailableMealCategory meal) {
    final isSelected = _isCategorySelected(slotId, meal.categoryId);
    return GestureDetector(
      onTap: () => _toggleCategory(slotId, meal.categoryId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing12,
          vertical: AppSizes.spacing6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen
              : AppColors.primaryGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSizes.radius20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : AppColors.primaryGreen.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 12, color: Colors.white),
              const SizedBox(width: 4),
            ] else
              Icon(
                _mealIcon(meal.categoryName),
                size: 12,
                color: AppColors.primaryGreen,
              ),
            const SizedBox(width: 4),
            Text(
              meal.categoryName,
              style: TextStyle(
                fontSize: AppTypography.fontSize13,
                fontWeight: isSelected
                    ? AppTypography.semiBold
                    : AppTypography.regular,
                color: isSelected ? Colors.white : AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Submit Button ────────────────────────────────────────────────────────

  Widget _buildSubmitButton(DeliverySlotState state) {
    final canSubmit = _hasValidSelection && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        onPressed: canSubmit ? () => _submit(state) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius4),
          ),
          elevation: canSubmit ? 2 : 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _hasValidSelection
                    ? 'Confirm Slot  ($_totalSelectedCount meal${_totalSelectedCount > 1 ? 's' : ''})'
                    : 'Select at least one meal',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.semiBold,
                  fontFamily: 'Lato',
                ),
              ),
      ),
    );
  }

  // ── Loading / Error States ───────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),
        for (int i = 0; i < 3; i++) ...[
          Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: AppSizes.spacing10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
          ),
        ],
        Container(
          height: AppSizes.buttonHeight,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSizes.radius4),
          ),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: AppSizes.spacing24),
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
            onTap: () => ref.read(deliverySlotApiProvider.notifier).refresh(),
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  IconData _slotIcon(String slotType) {
    switch (slotType) {
      case 'morning':
        return Icons.wb_sunny_outlined;
      case 'afternoon':
        return Icons.wb_cloudy_outlined;
      case 'night':
        return Icons.nightlight_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }

  IconData _mealIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.lunch_dining_outlined;
      case 'snacks':
        return Icons.cookie_outlined;
      case 'dinner':
        return Icons.nightlight_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  String _formatDeliveryDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}
