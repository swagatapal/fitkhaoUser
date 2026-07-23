import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../profile/models/delivery_address_model.dart';
import '../../../profile/providers/delivery_address_provider.dart';
import '../../models/delivery_slot_model.dart';
import '../../models/dish_category_model.dart';
import '../../models/weekly_delivery_slot_model.dart';
import '../../providers/delivery_slot_list_provider.dart';
import '../../providers/weekly_delivery_slot_provider.dart';

const Color _kAccent = Color(0xFFC66301);

/// Icon per meal-category name (fallback: generic meal icon).
IconData _categoryIcon(String name) {
  switch (name.toLowerCase()) {
    case 'breakfast':
      return Icons.free_breakfast_rounded;
    case 'lunch':
      return Icons.lunch_dining_rounded;
    case 'snacks':
    case 'snack':
      return Icons.bakery_dining_rounded;
    case 'dinner':
      return Icons.dinner_dining_rounded;
    case 'smoothie':
      return Icons.local_drink_rounded;
    case 'remedy':
      return Icons.medication_liquid_rounded;
    default:
      return Icons.restaurant_menu_rounded;
  }
}

/// One delivery of a day — mirrors an entry of the API's `slots` array:
/// a delivery slot, the meal categories it carries and its own address.
class _SlotEntry {
  String slotId;
  final Set<String> categoryIds;
  String addressId;

  _SlotEntry({
    this.slotId = '',
    Set<String>? categoryIds,
    this.addressId = '',
  }) : categoryIds = categoryIds ?? <String>{};

  bool get isComplete =>
      slotId.isNotEmpty && categoryIds.isNotEmpty && addressId.isNotEmpty;

  _SlotEntry copy() => _SlotEntry(
        slotId: slotId,
        categoryIds: {...categoryIds},
        addressId: addressId,
      );

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'categoryIds': categoryIds.toList(),
        'deliveryAddressId': addressId,
      };
}

/// Weekly delivery plan structured exactly like the API payload: per weekday a
/// list of slot entries, each carrying its meal categories and its own
/// delivery address. Backed by GET/POST/PUT /api/user/weekly-delivery-slots.
class DeliveryPlanManagerTab extends ConsumerStatefulWidget {
  const DeliveryPlanManagerTab({super.key});

  @override
  ConsumerState<DeliveryPlanManagerTab> createState() =>
      _DeliveryPlanManagerTabState();
}

class _DeliveryPlanManagerTabState extends ConsumerState<DeliveryPlanManagerTab>
    with AutomaticKeepAliveClientMixin {
  final Map<String, List<_SlotEntry>> _plans = {
    for (final w in Weekday.all) w.wire: <_SlotEntry>[],
  };
  bool _initialized = false;
  bool _hadPreference = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Addresses are needed for every slot entry; load if missing.
      if (ref.read(addressProvider).addresses.isEmpty) {
        ref.read(addressProvider.notifier).loadAddresses(silent: true);
      }
    });
  }

  void _initFrom(WeeklyDeliverySlotsResponse res) {
    for (final l in _plans.values) {
      l.clear();
    }
    for (final day in res.days) {
      final list = _plans[day.day];
      if (list == null) continue;
      for (final s in day.slots) {
        list.add(_SlotEntry(
          slotId: s.slotId,
          categoryIds: {...s.categoryIds},
          addressId: s.deliveryAddressId,
        ));
      }
    }
    _hadPreference = res.hasPreference;
    _initialized = true;
  }

  Future<void> _editEntry({
    required Weekday day,
    int? index,
    required List<DishCategory> categories,
    required List<DeliverySlotApiModel> slots,
    required List<DeliveryAddressModel> addresses,
  }) async {
    if (addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add a delivery address first.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final entries = _plans[day.wire]!;

    // Slots / categories already taken by the day's OTHER entries can't be
    // reused — one slot entry per slot, one delivery per meal.
    final usedSlotIds = <String>{
      for (var i = 0; i < entries.length; i++)
        if (i != index) entries[i].slotId,
    };
    final usedCategoryIds = <String>{
      for (var i = 0; i < entries.length; i++)
        if (i != index) ...entries[i].categoryIds,
    };

    final result = await showModalBottomSheet<_SlotEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SlotEntrySheet(
        dayLabel: day.label,
        initial: index == null ? _SlotEntry() : entries[index].copy(),
        categories: categories,
        slots: slots,
        addresses: addresses,
        usedSlotIds: usedSlotIds,
        usedCategoryIds: usedCategoryIds,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        entries.add(result);
      } else {
        entries[index] = result;
      }
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final days = <Map<String, dynamic>>[
      for (final w in Weekday.all)
        {
          'day': w.wire,
          'slots': [
            for (final e in _plans[w.wire]!)
              if (e.isComplete) e.toJson(),
          ],
        },
    ];

    final ok = await ref
        .read(weeklySlotsSubmitProvider.notifier)
        .submit(days: days, isUpdate: _hadPreference);
    if (!mounted) return;
    if (ok) {
      setState(() => _hadPreference = true);
      messenger.showSnackBar(const SnackBar(
        content: Text('Delivery plan saved.'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(ref.read(weeklySlotsSubmitProvider).error ??
            'Could not save your delivery plan.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Initialise the editable state once the saved preference arrives.
    ref.listen<AsyncValue<WeeklyDeliverySlotsResponse>>(
      weeklyDeliverySlotsProvider,
      (_, next) {
        final data = next.valueOrNull;
        if (data != null && !_initialized) {
          setState(() => _initFrom(data));
        }
      },
    );

    final weeklyAsync = ref.watch(weeklyDeliverySlotsProvider);
    final slotsAsync = ref.watch(deliverySlotListProvider);
    final categoriesAsync = ref.watch(dishCategoriesProvider);
    final addresses = ref.watch(addressProvider.select((s) => s.addresses));
    final submitting =
        ref.watch(weeklySlotsSubmitProvider.select((s) => s.isSubmitting));

    if (weeklyAsync.isLoading ||
        slotsAsync.isLoading ||
        categoriesAsync.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (weeklyAsync.hasError) {
      return _Message(
        icon: Icons.error_outline_rounded,
        message: 'Could not load your delivery plan.',
        onRetry: () => ref.invalidate(weeklyDeliverySlotsProvider),
      );
    }
    if (slotsAsync.hasError) {
      return _Message(
        icon: Icons.error_outline_rounded,
        message: 'Could not load delivery slots.',
        onRetry: () => ref.invalidate(deliverySlotListProvider),
      );
    }
    if (categoriesAsync.hasError) {
      return _Message(
        icon: Icons.error_outline_rounded,
        message: 'Could not load meal categories.',
        onRetry: () => ref.invalidate(dishCategoriesProvider),
      );
    }

    final slots = slotsAsync.valueOrNull ?? const <DeliverySlotApiModel>[];
    final categories = categoriesAsync.valueOrNull ?? const <DishCategory>[];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPaddingHorizontal,
                AppSizes.spacing16,
                AppSizes.screenPaddingHorizontal,
                AppSizes.spacing24),
            children: [
              const Text(
                'Weekly delivery plan',
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Add delivery slots per day — each with its meals and address.',
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontFamily: 'Lato',
                ),
              ),
              if (addresses.isEmpty) ...[
                const SizedBox(height: AppSizes.spacing12),
                _addressPrompt(),
              ],
              const SizedBox(height: AppSizes.spacing16),
              for (final w in Weekday.all)
                _DayCard(
                  dayLabel: w.label,
                  entries: _plans[w.wire]!,
                  categories: categories,
                  slots: slots,
                  addresses: addresses,
                  onAdd: () => _editEntry(
                    day: w,
                    categories: categories,
                    slots: slots,
                    addresses: addresses,
                  ),
                  onEdit: (i) => _editEntry(
                    day: w,
                    index: i,
                    categories: categories,
                    slots: slots,
                    addresses: addresses,
                  ),
                  onRemove: (i) => setState(() => _plans[w.wire]!.removeAt(i)),
                ),
            ],
          ),
        ),
        _SaveBar(
          label: _hadPreference ? 'Update delivery plan' : 'Save delivery plan',
          submitting: submitting,
          onSave: _save,
        ),
      ],
    );
  }

  Widget _addressPrompt() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: _kAccent, size: AppSizes.icon18),
          SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Text(
              'Add a delivery address in your profile to set up deliveries.',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                color: Color(0xFF795548),
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A weekday card listing its slot entries (slot → meals → address), with
/// add / edit / remove.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.dayLabel,
    required this.entries,
    required this.categories,
    required this.slots,
    required this.addresses,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final String dayLabel;
  final List<_SlotEntry> entries;
  final List<DishCategory> categories;
  final List<DeliverySlotApiModel> slots;
  final List<DeliveryAddressModel> addresses;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;

  String _slotLabel(String id) {
    final s = slots.where((e) => e.id == id);
    return s.isEmpty ? 'Slot' : '${s.first.slotName} · ${s.first.timeRange}';
  }

  String _mealsLabel(Set<String> ids) {
    final names = [
      for (final c in categories)
        if (ids.contains(c.id)) c.name,
    ];
    return names.isEmpty ? 'Meals' : names.join(', ');
  }

  String _addressLabel(String id) {
    final a = addresses.where((e) => e.id == id);
    if (a.isEmpty) return 'Address';
    final label = a.first.label;
    final cap = label.isEmpty
        ? 'Address'
        : '${label[0].toUpperCase()}${label.substring(1)}';
    return '$cap · ${a.first.formattedAddress}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(
          color: entries.isNotEmpty
              ? AppColors.primaryGreen.withValues(alpha: 0.4)
              : AppColors.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_week_rounded,
                  size: AppSizes.icon18,
                  color: entries.isNotEmpty
                      ? AppColors.primaryGreen
                      : AppColors.textTertiary),
              const SizedBox(width: AppSizes.spacing8),
              Text(
                dayLabel,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const Spacer(),
              if (entries.isEmpty)
                Text(
                  'No delivery',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize10,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontFamily: 'Lato',
                  ),
                ),
            ],
          ),
          for (var i = 0; i < entries.length; i++) ...[
            const SizedBox(height: AppSizes.spacing8),
            _EntryRow(
              slot: _slotLabel(entries[i].slotId),
              meals: _mealsLabel(entries[i].categoryIds),
              address: _addressLabel(entries[i].addressId),
              onEdit: () => onEdit(i),
              onRemove: () => onRemove(i),
            ),
          ],
          const SizedBox(height: AppSizes.spacing8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add_rounded, size: AppSizes.icon18),
              label: const Text('Add delivery slot',
                  style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.semiBold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.slot,
    required this.meals,
    required this.address,
    required this.onEdit,
    required this.onRemove,
  });

  final String slot;
  final String meals;
  final String address;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing8),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border:
            Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(Icons.local_shipping_rounded, slot, bold: true),
                const SizedBox(height: 3),
                _kv(Icons.restaurant_menu_rounded, meals),
                const SizedBox(height: 3),
                _kv(Icons.location_on_rounded, address),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.edit_rounded,
                  size: AppSizes.icon16, color: AppColors.primaryGreen),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: AppSizes.icon16, color: AppColors.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String text, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: AppSizes.icon14,
            color: AppColors.textSecondary.withValues(alpha: 0.8)),
        const SizedBox(width: AppSizes.spacing6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              fontWeight: bold ? AppTypography.semiBold : AppTypography.regular,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Editor for one slot entry, structured like the payload: pick the delivery
/// slot, the meal categories under it, then the address for this delivery.
class _SlotEntrySheet extends StatefulWidget {
  const _SlotEntrySheet({
    required this.dayLabel,
    required this.initial,
    required this.categories,
    required this.slots,
    required this.addresses,
    required this.usedSlotIds,
    required this.usedCategoryIds,
  });

  final String dayLabel;
  final _SlotEntry initial;
  final List<DishCategory> categories;
  final List<DeliverySlotApiModel> slots;
  final List<DeliveryAddressModel> addresses;

  /// Slots / categories already taken by the day's other entries.
  final Set<String> usedSlotIds;
  final Set<String> usedCategoryIds;

  @override
  State<_SlotEntrySheet> createState() => _SlotEntrySheetState();
}

class _SlotEntrySheetState extends State<_SlotEntrySheet> {
  late final _SlotEntry _draft = widget.initial.copy();

  bool get _valid => _draft.isComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.dayLabel} delivery',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize18,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                        Text(
                          'Slot, its meals and where to deliver them.',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize12,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.9),
                            fontFamily: 'Lato',
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded,
                        size: AppSizes.icon20, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  const _SheetLabel('Delivery slot'),
                  const SizedBox(height: AppSizes.spacing8),
                  for (final s in widget.slots)
                    _RadioTile(
                      title: s.slotName,
                      subtitle: widget.usedSlotIds.contains(s.id)
                          ? '${s.timeRange} — already added for this day'
                          : s.timeRange,
                      selected: _draft.slotId == s.id,
                      disabled: widget.usedSlotIds.contains(s.id),
                      onTap: () => setState(() => _draft.slotId = s.id),
                    ),
                  const SizedBox(height: AppSizes.spacing16),
                  const _SheetLabel('Meals in this delivery'),
                  const SizedBox(height: AppSizes.spacing8),
                  Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: [
                      for (final c in widget.categories)
                        _CategoryChip(
                          label: c.name,
                          icon: _categoryIcon(c.name),
                          selected: _draft.categoryIds.contains(c.id),
                          disabled: widget.usedCategoryIds.contains(c.id),
                          onTap: () => setState(() {
                            if (!_draft.categoryIds.remove(c.id)) {
                              _draft.categoryIds.add(c.id);
                            }
                          }),
                        ),
                    ],
                  ),
                  if (widget.usedCategoryIds.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.spacing6),
                    Text(
                      'Greyed meals are already covered by another slot today.',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize10,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.spacing16),
                  const _SheetLabel('Delivery address for this slot'),
                  const SizedBox(height: AppSizes.spacing8),
                  for (final a in widget.addresses)
                    _RadioTile(
                      title: a.label.isEmpty
                          ? 'Address'
                          : '${a.label[0].toUpperCase()}${a.label.substring(1)}',
                      subtitle: a.formattedAddress,
                      selected: _draft.addressId == a.id,
                      onTap: () => setState(() => _draft.addressId = a.id),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed:
                      _valid ? () => Navigator.of(context).pop(_draft) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.borderColor.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                  ),
                  child: Text(
                    _valid ? 'Done' : 'Pick slot, meals & address',
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.bold,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: AppTypography.fontSize14,
          fontWeight: AppTypography.bold,
          color: AppColors.textPrimary,
          fontFamily: 'Lato',
        ),
      );
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
          padding: const EdgeInsets.all(AppSizes.spacing12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryGreen.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            border: Border.all(
              color: selected
                  ? AppColors.primaryGreen
                  : AppColors.borderColor.withValues(alpha: 0.6),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: AppSizes.icon20,
                color:
                    selected ? AppColors.primaryGreen : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing12, vertical: AppSizes.spacing8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: selected ? AppColors.primaryGreen : AppColors.borderColor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: AppSizes.icon14,
                  color: selected ? Colors.white : AppColors.primaryGreen),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.semiBold,
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.submitting,
    required this.onSave,
  });

  final String label;
  final bool submitting;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing12,
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: ElevatedButton(
          onPressed: submitting ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppColors.borderColor.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
          ),
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    fontFamily: 'Lato',
                  ),
                ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 44, color: AppColors.textTertiary.withValues(alpha: 0.7)),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSizes.spacing12),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry',
                    style: TextStyle(
                        fontFamily: 'Lato', color: AppColors.primaryGreen)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
