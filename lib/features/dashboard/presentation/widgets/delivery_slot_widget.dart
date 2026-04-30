import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../delivery/models/delivery_slot_model.dart';
import '../../../delivery/providers/delivery_slot_provider.dart';

/// slotId → selected categoryIds
typedef SlotSelection = Map<String, List<String>>;

// ── Category restrictions per slot type ────────────────────────────────────
//
//  morning   → all categories allowed
//  afternoon → all except breakfast
//  night     → all except breakfast and lunch

bool _isAllowedInSlot(String slotType, String categoryName) {
  final name = categoryName.toLowerCase();
  switch (slotType) {
    case 'afternoon':
      return !name.contains('breakfast');
    case 'night':
      return !name.contains('breakfast') && !name.contains('lunch');
    default: // morning / unknown → all allowed
      return true;
  }
}

class DeliverySlotWidget extends ConsumerStatefulWidget {
  const DeliverySlotWidget({super.key});

  @override
  ConsumerState<DeliverySlotWidget> createState() => _DeliverySlotWidgetState();
}

class _DeliverySlotWidgetState extends ConsumerState<DeliverySlotWidget> {
  /// slotId → [categoryId, ...]
  SlotSelection _selection = {};
  bool _initialised = false;
  bool _isSubmitting = false;

  // ── Initialise from previous confirmed data ──────────────────────────────

  void _initialiseSelection(DeliverySlotState state) {
    if (_initialised) return;
    _initialised = true;
    if (state.previousSelection.isEmpty) return;
    _selection = {
      for (final p in state.previousSelection)
        if (p.slotId.isNotEmpty) p.slotId: List<String>.from(p.categoryIds),
    };
  }

  // ── Cross-slot exclusivity helpers ───────────────────────────────────────

  /// Returns the slotId that currently holds [categoryId], or null.
  String? _ownerSlotId(String categoryId) {
    for (final entry in _selection.entries) {
      if (entry.value.contains(categoryId)) return entry.key;
    }
    return null;
  }

  /// Whether [categoryId] is selected in [slotId].
  bool _isSelected(String slotId, String categoryId) =>
      (_selection[slotId] ?? []).contains(categoryId);

  /// Toggle category for a slot, enforcing exclusivity across slots.
  void _toggle(String slotId, String categoryId) {
    setState(() {
      if (_isSelected(slotId, categoryId)) {
        // Deselect
        final updated = List<String>.from(_selection[slotId] ?? [])
          ..remove(categoryId);
        if (updated.isEmpty) {
          _selection.remove(slotId);
        } else {
          _selection[slotId] = updated;
        }
      } else {
        // Remove from any other slot first (each category in one slot only)
        for (final key in _selection.keys.toList()) {
          if (_selection[key]!.contains(categoryId)) {
            final updated = List<String>.from(_selection[key]!)
              ..remove(categoryId);
            if (updated.isEmpty) {
              _selection.remove(key);
            } else {
              _selection[key] = updated;
            }
          }
        }
        // Assign to this slot
        _selection[slotId] = [...(_selection[slotId] ?? []), categoryId];
      }
    });
  }

  /// Select all allowed, unassigned-elsewhere categories for [slotId].
  void _selectAvailableForSlot(
      DeliverySlotApiModel slot, List<AvailableMealCategory> meals) {
    setState(() {
      for (final meal in meals) {
        if (!_isAllowedInSlot(slot.slotType, meal.categoryName)) continue;
        final owner = _ownerSlotId(meal.categoryId);
        if (owner != null && owner != slot.id) continue; // owned by another slot
        // Ensure it's in this slot
        if (!_isSelected(slot.id, meal.categoryId)) {
          _selection[slot.id] = [...(_selection[slot.id] ?? []), meal.categoryId];
        }
      }
    });
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  int get _totalSelected =>
      _selection.values.fold(0, (sum, ids) => sum + ids.length);

  bool get _hasValidSelection => _totalSelected > 0;

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit(DeliverySlotState state) async {
    if (!_hasValidSelection || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final items = _selection.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => ConfirmSlotItem(slotId: e.key, categoryIds: e.value))
        .toList();

    debugPrint('[DeliverySlotWidget] Submitting ${items.length} slot(s)');
    for (final item in items) {
      debugPrint('  slotId=${item.slotId} categories=${item.categoryIds}');
    }

    // TODO: Wire to confirm API
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

  // ── Build ────────────────────────────────────────────────────────────────

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
        _buildHeader(),
        const SizedBox(height: AppSizes.spacing12),
        if (state.alreadyConfirmed)
          _buildAlreadyConfirmedBanner(state)
        else if (!state.isWithinWindow)
          _buildOutOfWindowBanner(state)
        else ...[
          if (state.previousSelection.isNotEmpty)
            _buildPreviousSelectionHint(),
          _buildSlotCards(state),
          const SizedBox(height: AppSizes.spacing16),
          _buildSubmitButton(state),
        ],
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: const Text(
            'Delivery Slot',
            style: TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
        ),
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
              '$_totalSelected meal${_totalSelected > 1 ? 's' : ''} selected',
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

  // ── Slot cards ───────────────────────────────────────────────────────────

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
    final slotSelected = (_selection[slot.id] ?? []).isNotEmpty;

    // Partition meals for this slot
    final allowed = meals
        .where((m) => _isAllowedInSlot(slot.slotType, m.categoryName))
        .toList();
    final restricted = meals
        .where((m) => !_isAllowedInSlot(slot.slotType, m.categoryName))
        .toList();

    // Can "select all" if there's at least one allowed+unowned meal
    final canSelectAll = allowed.any((m) {
      final owner = _ownerSlotId(m.categoryId);
      return owner == null || owner == slot.id;
    });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: slotSelected ? AppColors.primaryGreen : AppColors.borderColor,
          width: slotSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: slotSelected
                ? AppColors.primaryGreen.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: slotSelected ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Slot header ─────────────────────────────────────────────────
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
                    color: slotSelected
                        ? AppColors.primaryGreen.withValues(alpha: 0.1)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  child: Icon(
                    _slotIcon(slot.slotType),
                    size: 18,
                    color: slotSelected
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
                        _slotLabel(slot.slotType),
                        style: TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.semiBold,
                          color: slotSelected
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
                if (canSelectAll)
                  GestureDetector(
                    onTap: () => _selectAvailableForSlot(slot, meals),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacing8,
                        vertical: AppSizes.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: slotSelected
                            ? AppColors.primaryGreen
                            : AppColors.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                      ),
                      child: Text(
                        'Select all',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize10,
                          fontWeight: AppTypography.semiBold,
                          color: slotSelected
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
          const Divider(height: 1),
          // ── Meal chips ──────────────────────────────────────────────────
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
                    children: [
                      for (final meal in allowed)
                        _buildMealChip(slot, meal, restricted: false),
                      for (final meal in restricted)
                        _buildMealChip(slot, meal, restricted: true),
                    ],
                  ),
          ),
          // ── Restriction note ────────────────────────────────────────────
          if (restricted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacing12, 0,
                AppSizes.spacing12, AppSizes.spacing10,
              ),
              child: Text(
                _restrictionNote(slot.slotType),
                style: const TextStyle(
                  fontSize: AppTypography.fontSize10,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMealChip(
    DeliverySlotApiModel slot,
    AvailableMealCategory meal, {
    required bool restricted,
  }) {
    final selected = _isSelected(slot.id, meal.categoryId);
    final ownerSlotId = _ownerSlotId(meal.categoryId);
    // Taken by another slot
    final takenByOther = ownerSlotId != null && ownerSlotId != slot.id;
    // Chip is interactive only if the meal is allowed and not taken elsewhere
    final interactive = !restricted && !takenByOther;

    Color bgColor;
    Color borderColor;
    Color textColor;
    Color iconColor;

    if (restricted) {
      bgColor = Colors.grey.withValues(alpha: 0.06);
      borderColor = Colors.grey.withValues(alpha: 0.2);
      textColor = AppColors.textSecondary.withValues(alpha: 0.5);
      iconColor = AppColors.textSecondary.withValues(alpha: 0.4);
    } else if (takenByOther) {
      bgColor = Colors.grey.withValues(alpha: 0.06);
      borderColor = Colors.grey.withValues(alpha: 0.2);
      textColor = AppColors.textSecondary.withValues(alpha: 0.6);
      iconColor = AppColors.textSecondary.withValues(alpha: 0.5);
    } else if (selected) {
      bgColor = AppColors.primaryGreen;
      borderColor = AppColors.primaryGreen;
      textColor = Colors.white;
      iconColor = Colors.white;
    } else {
      bgColor = AppColors.primaryGreen.withValues(alpha: 0.06);
      borderColor = AppColors.primaryGreen.withValues(alpha: 0.25);
      textColor = AppColors.primaryGreen;
      iconColor = AppColors.primaryGreen;
    }

    Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSizes.radius20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Icon(Icons.check, size: 12, color: iconColor),
            const SizedBox(width: 4),
          ] else if (restricted) ...[
            Icon(Icons.block, size: 12, color: iconColor),
            const SizedBox(width: 4),
          ] else if (takenByOther) ...[
            Icon(Icons.lock_outline, size: 12, color: iconColor),
            const SizedBox(width: 4),
          ] else ...[
            Icon(_mealIcon(meal.categoryName), size: 12, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(
            meal.categoryName,
            style: TextStyle(
              fontSize: AppTypography.fontSize13,
              fontWeight: selected
                  ? AppTypography.semiBold
                  : AppTypography.regular,
              color: textColor,
              fontFamily: 'Lato',
              decoration:
                  restricted ? TextDecoration.lineThrough : TextDecoration.none,
              decorationColor: textColor,
            ),
          ),
        ],
      ),
    );

    if (!interactive) return chip;

    return GestureDetector(
      onTap: () => _toggle(slot.id, meal.categoryId),
      child: chip,
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton(DeliverySlotState state) {
    final canSubmit = _hasValidSelection && !_isSubmitting;
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        onPressed: canSubmit ? () => _submit(state) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor:
              AppColors.primaryGreen.withValues(alpha: 0.4),
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
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                _hasValidSelection
                    ? 'Confirm Slot  ($_totalSelected meal${_totalSelected > 1 ? 's' : ''})'
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

  // ── Banners ───────────────────────────────────────────────────────────────

  Widget _buildAlreadyConfirmedBanner(DeliverySlotState state) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border:
            Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
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
            ...state.previousSelection
                .map((sel) => _buildConfirmedSlotRow(sel, state)),
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
                  ...state.previousSelection
                      .map((sel) => _buildConfirmedSlotRow(sel, state)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousSelectionHint() {
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
          children: const [
            Icon(Icons.info_outline, size: 16, color: Color(0xFF1565C0)),
            SizedBox(width: AppSizes.spacing8),
            Expanded(
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

  // ── Skeleton / Error ──────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        for (int i = 0; i < 3; i++)
          Container(
            height: 110,
            margin: const EdgeInsets.only(bottom: AppSizes.spacing10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
          ),
        Container(
          height: AppSizes.buttonHeight,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSizes.radius4),
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
        border:
            Border.all(color: AppColors.errorColor.withValues(alpha: 0.2)),
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

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  String _slotLabel(String slotType) {
    switch (slotType) {
      case 'morning':
        return 'Morning';
      case 'afternoon':
        return 'Afternoon';
      case 'night':
        return 'Night';
      default:
        return 'Delivery';
    }
  }

  String _restrictionNote(String slotType) {
    switch (slotType) {
      case 'afternoon':
        return 'Breakfast is not delivered in the afternoon slot.';
      case 'night':
        return 'Breakfast and lunch are not delivered in the night slot.';
      default:
        return '';
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
}
