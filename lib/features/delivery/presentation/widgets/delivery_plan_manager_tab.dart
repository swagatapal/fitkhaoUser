import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../profile/models/delivery_address_model.dart';
import '../../../profile/presentation/screens/address_form_screen.dart';
import '../../../profile/providers/delivery_address_provider.dart';
import '../../models/delivery_slot_model.dart';
import '../../models/dish_category_model.dart';
import '../../models/weekly_delivery_slot_model.dart';
import '../../providers/delivery_slot_list_provider.dart';
import '../../providers/serviceability_provider.dart';
import '../../providers/weekly_delivery_slot_provider.dart';

const Color _kAccent = Color(0xFFC66301);

/// Icon per meal-category name.
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

/// Icon + priority for a slot group (morning / afternoon / night).
({IconData icon, int order}) _groupVisual(String key) {
  switch (key.toLowerCase()) {
    case 'morning':
      return (icon: Icons.wb_sunny_rounded, order: 0);
    case 'afternoon':
      return (icon: Icons.wb_twilight_rounded, order: 1);
    case 'night':
    case 'evening':
      return (icon: Icons.nightlight_round, order: 2);
    default:
      return (icon: Icons.schedule_rounded, order: 3);
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// "Home · V968+MVV, Chib, 712136" from a populated address label + summary.
String _addressText(String label, String summary) {
  final l = label.isEmpty ? '' : _capitalize(label);
  if (l.isEmpty) return summary;
  if (summary.isEmpty) return l;
  return '$l · $summary';
}

/// Maps a slot name (e.g. "Morning A") to its group key for the group icon.
String _groupKeyFromName(String slotName) {
  final n = slotName.toLowerCase();
  if (n.contains('morning')) return 'morning';
  if (n.contains('afternoon')) return 'afternoon';
  if (n.contains('night') || n.contains('evening')) return 'night';
  return '';
}

/// A slot group presented as one wizard step (e.g. "Morning" → [Morning A/B]).
class _SlotGroup {
  final String key; // 'morning'
  final String label; // 'Morning'
  final IconData icon;
  final List<DeliverySlotApiModel> slots;

  const _SlotGroup({
    required this.key,
    required this.label,
    required this.icon,
    required this.slots,
  });
}

/// Groups the flat slot catalogue into ordered morning/afternoon/night steps.
List<_SlotGroup> _buildSlotGroups(List<DeliverySlotApiModel> slots) {
  final byKey = <String, List<DeliverySlotApiModel>>{};
  for (final s in slots) {
    byKey.putIfAbsent(s.groupKey, () => []).add(s);
  }
  final groups = byKey.entries.map((e) {
    final v = _groupVisual(e.key);
    final list = [...e.value]..sort((a, b) => a.sort.compareTo(b.sort));
    return (
      group: _SlotGroup(
          key: e.key, label: _capitalize(e.key), icon: v.icon, slots: list),
      order: v.order,
    );
  }).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return groups.map((g) => g.group).toList();
}

/// The wire value of today's weekday (Weekday.all is sunday-first).
String _todayWire() {
  const wires = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];
  return wires[DateTime.now().weekday - 1];
}

/// One delivery of a day — mirrors an entry of the API's `slots` array.
///
/// [slotId]/[categoryIds]/[addressId] are the source of truth (what gets saved).
/// The remaining fields are the populated display strings the GET response
/// carries; they stay empty for locally-built entries, which then fall back to
/// provider lookups for display.
class _SlotEntry {
  String slotId;
  final Set<String> categoryIds;
  String addressId;

  // Populated display data (GET only) — empty for wizard-created entries.
  String slotName;
  String slotTimeRange;
  List<String> mealNames;
  String addressText;

  _SlotEntry({
    this.slotId = '',
    Set<String>? categoryIds,
    this.addressId = '',
    this.slotName = '',
    this.slotTimeRange = '',
    List<String>? mealNames,
    this.addressText = '',
  })  : categoryIds = categoryIds ?? <String>{},
        mealNames = mealNames ?? <String>[];

  bool get isComplete =>
      slotId.isNotEmpty && categoryIds.isNotEmpty && addressId.isNotEmpty;

  _SlotEntry copy() => _SlotEntry(
        slotId: slotId,
        categoryIds: {...categoryIds},
        addressId: addressId,
        slotName: slotName,
        slotTimeRange: slotTimeRange,
        mealNames: [...mealNames],
        addressText: addressText,
      );

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'categoryIds': categoryIds.toList(),
        'deliveryAddressId': addressId,
      };
}

/// Weekly delivery plan: a weekday tab bar (defaulting to today) + a guided
/// wizard to set morning/afternoon/night deliveries, each with its meals and
/// address. Backed by GET/POST/PUT /api/user/weekly-delivery-slots.
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
  late String _selectedDay = _todayWire();
  bool _initialized = false;
  bool _hadPreference = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
          slotName: s.slotName,
          slotTimeRange: s.slotTimeRange,
          mealNames: [
            for (final c in s.categories)
              if (c.name.isNotEmpty) c.name,
          ],
          addressText: _addressText(s.addressLabel, s.addressSummary),
        ));
      }
    }
    _hadPreference = res.hasPreference;
    _initialized = true;
  }

  Weekday get _day => Weekday.all.firstWhere((w) => w.wire == _selectedDay);

  /// Days that have at least one complete slot entry.
  int get _plannedDayCount =>
      Weekday.all.where((w) => _plans[w.wire]!.any((e) => e.isComplete)).length;

  /// Whether every available meal category has been chosen somewhere in the
  /// plan — a save requirement alongside all 7 days being configured. Returns
  /// false while categories are still loading (nothing to confirm against).
  bool _allMealTypesCovered(List<DishCategory> categories) {
    if (categories.isEmpty) return false;
    final chosen = <String>{};
    for (final list in _plans.values) {
      for (final e in list) {
        if (e.isComplete) chosen.addAll(e.categoryIds);
      }
    }
    return categories.every((c) => chosen.contains(c.id));
  }

  Future<void> _runWizard({
    required List<_SlotGroup> groups,
    required List<DishCategory> categories,
    required List<DeliveryAddressModel> addresses,
  }) async {
    // Addresses may be empty — the wizard's address step lets the user add one
    // inline, so we no longer block entry here.
    if (groups.isEmpty) return;

    final result = await showModalBottomSheet<List<_SlotEntry>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryWizardSheet(
        dayLabel: _day.label,
        groups: groups,
        categories: categories,
        existing: _plans[_selectedDay]!,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _plans[_selectedDay] = result);

    // "Copy to other days?" — only meaningful once the day has deliveries.
    if (result.any((e) => e.isComplete)) {
      await _promptCopy(_day);
    }
  }

  Future<void> _promptCopy(Weekday source) async {
    final targets = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CopyDaySheet(
        sourceLabel: source.label,
        targets: [
          for (final w in Weekday.all)
            if (w.wire != source.wire)
              (day: w, hasPlan: _plans[w.wire]!.isNotEmpty),
        ],
      ),
    );
    if (targets == null || targets.isEmpty || !mounted) return;
    setState(() {
      for (final t in targets) {
        _plans[t] = [for (final e in _plans[source.wire]!) e.copy()];
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${source.label} plan copied to '
          '${targets.length} ${targets.length == 1 ? 'day' : 'days'}.'),
      backgroundColor: AppColors.primaryGreen,
      behavior: SnackBarBehavior.floating,
    ));
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

    // React to LATER changes (e.g. after a save/refresh) that arrive while the
    // tab is already mounted.
    ref.listen<AsyncValue<WeeklyDeliverySlotsResponse>>(
      weeklyDeliverySlotsProvider,
      (_, next) {
        final data = next.valueOrNull;
        if (data != null && !_initialized) setState(() => _initFrom(data));
      },
    );

    final weeklyAsync = ref.watch(weeklyDeliverySlotsProvider);
    final slotsAsync = ref.watch(deliverySlotListProvider);
    final categoriesAsync = ref.watch(dishCategoriesProvider);
    final addresses = ref.watch(addressProvider.select((s) => s.addresses));
    final submitting =
        ref.watch(weeklySlotsSubmitProvider.select((s) => s.isSubmitting));

    // Initialise from data that's ALREADY resolved when this tab mounts — the
    // listener above only fires on subsequent changes, and the provider is kept
    // warm elsewhere (the tab bar), so it's usually loaded before we get here.
    final weeklyData = weeklyAsync.valueOrNull;
    if (weeklyData != null && !_initialized) {
      _initFrom(weeklyData); // mutates state during build (one-time init only)
    }

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
    final groups = _buildSlotGroups(slots);
    final entries = _plans[_selectedDay]!;

    final allDaysSet = _plannedDayCount == Weekday.all.length;
    final mealsCovered = _allMealTypesCovered(categories);
    final canSave = allDaysSet && mealsCovered;

    final String saveLabel;
    if (!allDaysSet) {
      saveLabel = 'Set all 7 days to save ($_plannedDayCount/7)';
    } else if (!mealsCovered) {
      saveLabel = 'Choose all meal types to save';
    } else {
      saveLabel =
          _hadPreference ? 'Update delivery plan' : 'Save delivery plan';
    }

    return Column(
      children: [
        // ── Weekday tabs ──
        _WeekdayTabs(
          selected: _selectedDay,
          plannedWires: {
            for (final w in Weekday.all)
              if (_plans[w.wire]!.any((e) => e.isComplete)) w.wire,
          },
          onSelect: (wire) => setState(() => _selectedDay = wire),
        ),
        // ── Selected day ──
        Expanded(
          child: entries.any((e) => e.isComplete)
              ? _DayPlanView(
                  entries: entries,
                  categories: categories,
                  slots: slots,
                  addresses: addresses,
                  onEdit: () => _runWizard(
                    groups: groups,
                    categories: categories,
                    addresses: addresses,
                  ),
                  onCopy: () => _promptCopy(_day),
                  onClear: () =>
                      setState(() => _plans[_selectedDay] = <_SlotEntry>[]),
                )
              : _EmptyDayView(
                  dayLabel: _day.label,
                  onSetup: () => _runWizard(
                    groups: groups,
                    categories: categories,
                    addresses: addresses,
                  ),
                  addressMissing: addresses.isEmpty,
                ),
        ),
        _SaveBar(
          label: saveLabel,
          enabled: canSave,
          submitting: submitting,
          onSave: _save,
        ),
      ],
    );
  }
}

/// Horizontal weekday selector with a "planned" dot per day.
class _WeekdayTabs extends StatelessWidget {
  const _WeekdayTabs({
    required this.selected,
    required this.plannedWires,
    required this.onSelect,
  });

  final String selected;
  final Set<String> plannedWires;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPaddingHorizontal),
          itemCount: Weekday.all.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSizes.spacing6),
          itemBuilder: (_, i) {
            final w = Weekday.all[i];
            final isSelected = w.wire == selected;
            final planned = plannedWires.contains(w.wire);
            return GestureDetector(
              onTap: () => onSelect(w.wire),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSizes.spacing12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.borderColor.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      w.label.substring(0, 3),
                      style: TextStyle(
                        fontSize: AppTypography.fontSize13,
                        fontWeight: AppTypography.bold,
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    if (planned) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.check_circle_rounded,
                          size: 13,
                          color: isSelected
                              ? Colors.white
                              : AppColors.primaryGreen),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Empty state for a day with no deliveries set.
class _EmptyDayView extends StatelessWidget {
  const _EmptyDayView({
    required this.dayLabel,
    required this.onSetup,
    required this.addressMissing,
  });

  final String dayLabel;
  final VoidCallback onSetup;
  final bool addressMissing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.spacing24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded,
                size: 40, color: AppColors.primaryGreen),
          ),
          const SizedBox(height: AppSizes.spacing16),
          Text(
            'No deliveries set for $dayLabel',
            style: const TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing6),
          Text(
            'Set up morning, afternoon and night deliveries — each with its '
            'meals and address.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
              fontFamily: 'Lato',
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSizes.spacing20),
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: onSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: AppSizes.icon20),
              label: const Text('Add delivery slot',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    fontFamily: 'Lato',
                  )),
            ),
          ),
          if (addressMissing) ...[
            const SizedBox(height: AppSizes.spacing12),
            Text(
              'Add a delivery address in your profile first.',
              style: TextStyle(
                fontSize: AppTypography.fontSize10,
                color: _kAccent.withValues(alpha: 0.9),
                fontFamily: 'Lato',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Read-only view of a configured day's deliveries + actions.
class _DayPlanView extends StatelessWidget {
  const _DayPlanView({
    required this.entries,
    required this.categories,
    required this.slots,
    required this.addresses,
    required this.onEdit,
    required this.onCopy,
    required this.onClear,
  });

  final List<_SlotEntry> entries;
  final List<DishCategory> categories;
  final List<DeliverySlotApiModel> slots;
  final List<DeliveryAddressModel> addresses;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onClear;

  DeliverySlotApiModel? _slot(String id) {
    for (final s in slots) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// "Morning A · 7:00 AM - 8:00 AM" — populated data first, else slot lookup.
  String _slotTitle(_SlotEntry e) {
    if (e.slotName.isNotEmpty) {
      return e.slotTimeRange.isEmpty
          ? e.slotName
          : '${e.slotName} · ${e.slotTimeRange}';
    }
    final s = _slot(e.slotId);
    if (s == null) return 'Delivery';
    return s.timeRange.isEmpty ? s.slotName : '${s.slotName} · ${s.timeRange}';
  }

  String _slotGroupKey(_SlotEntry e) {
    final name =
        e.slotName.isNotEmpty ? e.slotName : (_slot(e.slotId)?.slotName ?? '');
    final key = _groupKeyFromName(name);
    return key.isNotEmpty ? key : (_slot(e.slotId)?.groupKey ?? '');
  }

  String _mealsLabel(_SlotEntry e) {
    if (e.mealNames.isNotEmpty) return e.mealNames.join(', ');
    final names = [
      for (final c in categories)
        if (e.categoryIds.contains(c.id)) c.name,
    ];
    return names.isEmpty ? 'Meals' : names.join(', ');
  }

  String _addressLabel(_SlotEntry e) {
    if (e.addressText.isNotEmpty) return e.addressText;
    final a = addresses.where((x) => x.id == e.addressId);
    if (a.isEmpty) return 'Address';
    final label = a.first.label;
    return '${label.isEmpty ? 'Address' : _capitalize(label)} · '
        '${a.first.formattedAddress}';
  }

  @override
  Widget build(BuildContext context) {
    final valid = entries.where((e) => e.isComplete).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing16,
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing24),
      children: [
        for (final e in valid)
          _DeliveryCard(
            title: _slotTitle(e),
            groupKey: _slotGroupKey(e),
            meals: _mealsLabel(e),
            address: _addressLabel(e),
          ),
        const SizedBox(height: AppSizes.spacing8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: AppSizes.icon16),
                label: const Text('Edit',
                    style: TextStyle(
                        fontFamily: 'Lato',
                        fontWeight: AppTypography.semiBold)),
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: AppSizes.icon16),
                label: const Text('Copy',
                    style: TextStyle(
                        fontFamily: 'Lato',
                        fontWeight: AppTypography.semiBold)),
              ),
            ),
            // const SizedBox(width: AppSizes.spacing8),
            // IconButton(
            //   onPressed: onClear,
            //   icon: const Icon(Icons.delete_outline_rounded,
            //       color: AppColors.errorColor),
            //   tooltip: 'Clear this day',
            // ),
          ],
        ),
      ],
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.title,
    required this.groupKey,
    required this.meals,
    required this.address,
  });

  final String title;
  final String groupKey;
  final String meals;
  final String address;

  @override
  Widget build(BuildContext context) {
    final groupIcon = groupKey.isEmpty
        ? Icons.local_shipping_rounded
        : _groupVisual(groupKey).icon;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border:
            Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                child: Icon(groupIcon,
                    size: AppSizes.icon18, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: Text(
                  title.isEmpty ? 'Delivery' : title,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          _kv(Icons.restaurant_menu_rounded, meals),
          const SizedBox(height: 3),
          _kv(Icons.location_on_rounded, address),
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String text) {
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
              color: AppColors.textPrimary.withValues(alpha: 0.9),
              fontFamily: 'Lato',
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Guided wizard — one step per slot group (Morning → Afternoon → Night).
// Each step progressively reveals: slot → meals → address.
// ═══════════════════════════════════════════════════════════════════════════

class _DeliveryWizardSheet extends ConsumerStatefulWidget {
  const _DeliveryWizardSheet({
    required this.dayLabel,
    required this.groups,
    required this.categories,
    required this.existing,
  });

  final String dayLabel;
  final List<_SlotGroup> groups;
  final List<DishCategory> categories;
  final List<_SlotEntry> existing;

  @override
  ConsumerState<_DeliveryWizardSheet> createState() =>
      _DeliveryWizardSheetState();
}

class _DeliveryWizardSheetState extends ConsumerState<_DeliveryWizardSheet> {
  int _step = 0;
  late final List<_SlotEntry> _working;
  late final List<bool> _skipped;

  @override
  void initState() {
    super.initState();
    // Pre-fill each group from any existing entry whose slot belongs to it.
    _working = [
      for (final g in widget.groups) _existingFor(g)?.copy() ?? _SlotEntry(),
    ];
    _skipped = List<bool>.filled(widget.groups.length, false);
  }

  _SlotEntry? _existingFor(_SlotGroup g) {
    final ids = g.slots.map((s) => s.id).toSet();
    for (final e in widget.existing) {
      if (ids.contains(e.slotId)) return e;
    }
    return null;
  }

  _SlotGroup get _group => widget.groups[_step];
  _SlotEntry get _entry => _working[_step];
  bool get _isLast => _step == widget.groups.length - 1;
  bool get _canContinue => _skipped[_step] || _entry.isComplete;

  void _finish() {
    final entries = <_SlotEntry>[
      for (var i = 0; i < widget.groups.length; i++)
        if (!_skipped[i] && _working[i].isComplete) _working[i],
    ];
    Navigator.of(context).pop(entries);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      setState(() => _step++);
    }
  }

  void _skip() {
    setState(() {
      _skipped[_step] = true;
      _working[_step] = _SlotEntry();
    });
    _next();
  }

  void _back() => setState(() => _step--);

  /// Opens the add-address screen; the newly created address is auto-selected
  /// for this delivery when the user returns.
  Future<void> _addAddress() async {
    final before = ref.read(addressProvider).addresses.map((a) => a.id).toSet();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AddressFormScreen()),
    );
    if (!mounted) return;
    final added = ref
        .read(addressProvider)
        .addresses
        .where((a) => !before.contains(a.id))
        .toList();
    if (added.isEmpty) return;

    // Auto-select the new address only if it lands in a serviceable zone.
    final a = added.first;
    final serviceable = await ref.read(
      addressServiceabilityProvider(
        ServiceabilityQuery(a.latitude, a.longitude),
      ).future,
    );
    if (!mounted) return;
    if (serviceable) {
      setState(() => _entry.addressId = a.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("This address isn't in a serviceable area yet."),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live address list — reflects an address added from within this sheet.
    final addresses = ref.watch(addressProvider.select((s) => s.addresses));
    final skipped = _skipped[_step];
    final slotChosen = _entry.slotId.isNotEmpty;
    final mealsChosen = _entry.categoryIds.isNotEmpty;

    // Meals already assigned to another slot this day are hidden here — each
    // meal is delivered once per day.
    final usedByOtherSteps = <String>{
      for (var i = 0; i < _working.length; i++)
        if (i != _step && !_skipped[i]) ..._working[i].categoryIds,
    };
    final availableCategories = [
      for (final c in widget.categories)
        if (!usedByOtherSteps.contains(c.id)) c,
    ];

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
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  if (_step > 0)
                    GestureDetector(
                      onTap: _back,
                      child: const Padding(
                        padding: EdgeInsets.only(right: AppSizes.spacing8),
                        child: Icon(Icons.arrow_back_rounded,
                            size: AppSizes.icon20,
                            color: AppColors.textSecondary),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.dayLabel} · ${_group.label}',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize18,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                        Text(
                          'Step ${_step + 1} of ${widget.groups.length}',
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
            // ── Progress stepper ──
            _StepDots(
              groups: widget.groups,
              current: _step,
              skipped: _skipped,
              completed: [for (final e in _working) e.isComplete],
            ),
            const Divider(height: 1),
            // ── Body: progressive reveal ──
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  _StepLabel(
                      1, 'Choose your ${_group.label.toLowerCase()} slot'),
                  const SizedBox(height: AppSizes.spacing8),
                  for (final s in _group.slots)
                    _RadioTile(
                      title: s.slotName,
                      subtitle: s.timeRange,
                      selected: _entry.slotId == s.id,
                      onTap: () => setState(() {
                        _skipped[_step] = false;
                        _entry.slotId = s.id;
                      }),
                    ),
                  if (slotChosen && !skipped) ...[
                    const SizedBox(height: AppSizes.spacing16),
                    _StepLabel(2, 'Which meals in this delivery?'),
                    const SizedBox(height: AppSizes.spacing8),
                    if (availableCategories.isEmpty)
                      Text(
                        'All meals are already assigned to other slots today.',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                          fontFamily: 'Lato',
                        ),
                      )
                    else
                      Wrap(
                        spacing: AppSizes.spacing8,
                        runSpacing: AppSizes.spacing8,
                        children: [
                          for (final c in availableCategories)
                            _CategoryChip(
                              label: c.name,
                              icon: _categoryIcon(c.name),
                              selected: _entry.categoryIds.contains(c.id),
                              onTap: () => setState(() {
                                if (!_entry.categoryIds.remove(c.id)) {
                                  _entry.categoryIds.add(c.id);
                                }
                              }),
                            ),
                        ],
                      ),
                  ],
                  if (slotChosen && mealsChosen && !skipped) ...[
                    const SizedBox(height: AppSizes.spacing16),
                    Row(
                      children: [
                        Expanded(child: _StepLabel(3, 'Delivery address')),
                        _AddAddressButton(onTap: _addAddress),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spacing8),
                    if (addresses.isEmpty)
                      _AddAddressPrompt(onTap: _addAddress)
                    else
                      for (final a in addresses)
                        _AddressTile(
                          address: a,
                          selected: _entry.addressId == a.id,
                          onSelect: () =>
                              setState(() => _entry.addressId = a.id),
                          onDeselect: () {
                            if (_entry.addressId == a.id) {
                              setState(() => _entry.addressId = '');
                            }
                          },
                        ),
                  ],
                ],
              ),
            ),
            // ── Footer ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  // TextButton(
                  //   onPressed: _skip,
                  //   style: TextButton.styleFrom(
                  //     foregroundColor: AppColors.textSecondary,
                  //     minimumSize: const Size(0, AppSizes.buttonHeight),
                  //   ),
                  //   child: const Text('Skip',
                  //       style: TextStyle(
                  //           fontFamily: 'Lato',
                  //           fontWeight: AppTypography.semiBold)),
                  // ),
                  // const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: SizedBox(
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _canContinue ? _next : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.borderColor.withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radius8),
                          ),
                        ),
                        child: Text(
                          _isLast ? 'Finish' : 'Continue',
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
          ],
        ),
      ),
    );
  }
}

/// Segmented progress dots for the wizard (Morning → Afternoon → Night).
class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.groups,
    required this.current,
    required this.skipped,
    required this.completed,
  });

  final List<_SlotGroup> groups;
  final int current;
  final List<bool> skipped;
  final List<bool> completed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      _dot(i),
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i < current
                              ? AppColors.primaryGreen
                              : AppColors.borderColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    groups[i].label,
                    style: TextStyle(
                      fontSize: AppTypography.fontSize10,
                      fontWeight: i == current
                          ? AppTypography.bold
                          : AppTypography.regular,
                      color: i == current
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary.withValues(alpha: 0.8),
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(int i) {
    final done = i < current && (completed[i] || skipped[i]);
    final active = i == current;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active || done
            ? AppColors.primaryGreen
            : AppColors.borderColor.withValues(alpha: 0.3),
      ),
      child: Icon(
        done ? Icons.check_rounded : groups[i].icon,
        size: 13,
        color: active || done ? Colors.white : AppColors.textSecondary,
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: AppTypography.fontSize10,
              fontWeight: AppTypography.bold,
              color: AppColors.primaryGreen,
              fontFamily: 'Lato',
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spacing8),
        Text(
          text,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }
}

/// Compact "Add new" action shown beside the delivery-address step label.
class _AddAddressButton extends StatelessWidget {
  const _AddAddressButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.add_location_alt_rounded, size: AppSizes.icon16),
      label: const Text(
        'Add new',
        style: TextStyle(
          fontFamily: 'Lato',
          fontSize: AppTypography.fontSize12,
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }
}

/// Empty-state tile prompting the user to add their first address inline.
class _AddAddressPrompt extends StatelessWidget {
  const _AddAddressPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_location_alt_outlined,
                size: AppSizes.icon20, color: AppColors.primaryGreen),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Text(
                'Add a delivery address to continue',
                style: TextStyle(
                  fontSize: AppTypography.fontSize13,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary.withValues(alpha: 0.9),
                  fontFamily: 'Lato',
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: AppSizes.icon20, color: AppColors.primaryGreen),
          ],
        ),
      ),
    );
  }
}

/// Address option gated by a live serviceability check.
///
/// While the coordinate is verified the tile shows a spinner and is inert;
/// serviceable addresses become selectable with a green note; non-serviceable
/// (or unpinned) addresses are greyed out and cannot be selected. A failed
/// check offers a tap-to-retry. If a currently-selected address resolves to
/// non-serviceable, [onDeselect] clears it so the step can't be completed.
class _AddressTile extends ConsumerWidget {
  const _AddressTile({
    required this.address,
    required this.selected,
    required this.onSelect,
    required this.onDeselect,
  });

  final DeliveryAddressModel address;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDeselect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title =
        address.label.isEmpty ? 'Address' : _capitalize(address.label);
    final query = ServiceabilityQuery(address.latitude, address.longitude);

    if (!query.hasCoordinates) {
      return _AddressTileShell(
        title: title,
        subtitle: address.formattedAddress,
        selected: false,
        enabled: false,
        leading: const Icon(Icons.location_off_rounded,
            size: AppSizes.icon20, color: AppColors.textTertiary),
        note: const _ServiceNote(
          icon: Icons.warning_amber_rounded,
          text: 'Location not pinned — edit this address to add it',
          color: _kAccent,
        ),
        onTap: null,
      );
    }

    final async = ref.watch(addressServiceabilityProvider(query));

    return async.when(
      loading: () => _AddressTileShell(
        title: title,
        subtitle: address.formattedAddress,
        selected: selected,
        enabled: false,
        leading: const SizedBox(
          width: AppSizes.icon20,
          height: AppSizes.icon20,
          child: Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryGreen),
          ),
        ),
        note: const _ServiceNote(
          icon: Icons.pending_outlined,
          text: 'Checking availability…',
          color: AppColors.textSecondary,
        ),
        onTap: null,
      ),
      error: (_, __) => _AddressTileShell(
        title: title,
        subtitle: address.formattedAddress,
        selected: false,
        enabled: true,
        leading: const Icon(Icons.refresh_rounded,
            size: AppSizes.icon20, color: _kAccent),
        note: const _ServiceNote(
          icon: Icons.error_outline_rounded,
          text: "Couldn't verify availability — tap to retry",
          color: _kAccent,
        ),
        onTap: () => ref.invalidate(addressServiceabilityProvider(query)),
      ),
      data: (serviceable) {
        // A selected address that turns out non-serviceable is cleared so the
        // user can't proceed with it.
        if (!serviceable && selected) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onDeselect());
        }
        return _AddressTileShell(
          title: title,
          subtitle: address.formattedAddress,
          selected: selected && serviceable,
          enabled: serviceable,
          leading: Icon(
            serviceable
                ? (selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded)
                : Icons.block_rounded,
            size: AppSizes.icon20,
            color: serviceable
                ? (selected ? AppColors.primaryGreen : AppColors.textTertiary)
                : AppColors.errorColor,
          ),
          note: serviceable
              ? const _ServiceNote(
                  icon: Icons.check_circle_rounded,
                  text: 'Deliverable to this address',
                  color: AppColors.primaryGreen,
                )
              : const _ServiceNote(
                  icon: Icons.do_not_disturb_on_outlined,
                  text: 'Not available in this area',
                  color: AppColors.errorColor,
                ),
          onTap: serviceable ? onSelect : null,
        );
      },
    );
  }
}

/// Shared visual shell for [_AddressTile] states.
class _AddressTileShell extends StatelessWidget {
  const _AddressTileShell({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.leading,
    required this.note,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final Widget leading;
  final Widget note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled || selected ? 1 : 0.6,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: AppSizes.icon20,
                  height: AppSizes.icon20,
                  child: Center(child: leading)),
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
                    const SizedBox(height: 4),
                    note,
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

/// A small icon + text status line used inside [_AddressTileShell].
class _ServiceNote extends StatelessWidget {
  const _ServiceNote({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppSizes.icon14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: AppTypography.fontSize10,
              fontWeight: AppTypography.semiBold,
              color: color,
              fontFamily: 'Lato',
            ),
          ),
        ),
      ],
    );
  }
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              color: selected ? AppColors.primaryGreen : AppColors.textTertiary,
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
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Copy-to-other-days sheet
// ═══════════════════════════════════════════════════════════════════════════

class _CopyDaySheet extends StatefulWidget {
  const _CopyDaySheet({required this.sourceLabel, required this.targets});

  final String sourceLabel;
  final List<({Weekday day, bool hasPlan})> targets;

  @override
  State<_CopyDaySheet> createState() => _CopyDaySheetState();
}

class _CopyDaySheetState extends State<_CopyDaySheet> {
  final Set<String> _selected = {};

  bool get _allSelected => _selected.length == widget.targets.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(widget.targets.map((t) => t.day.wire));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                          'Copy ${widget.sourceLabel} to…',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize18,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                        Text(
                          'Reuse this day\'s deliveries on other days.',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Days',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                      fontFamily: 'Lato',
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _toggleAll,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _allSelected ? 'Clear all' : 'Select all',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                children: [
                  for (final t in widget.targets)
                    _CopyTargetTile(
                      label: t.day.label,
                      note: t.hasPlan ? 'Has a plan — will be replaced' : '',
                      selected: _selected.contains(t.day.wire),
                      onTap: () => setState(() {
                        if (!_selected.remove(t.day.wire)) {
                          _selected.add(t.day.wire);
                        }
                      }),
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
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected),
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
                    _selected.isEmpty
                        ? 'Select days to copy to'
                        : 'Copy to ${_selected.length} '
                            '${_selected.length == 1 ? 'day' : 'days'}',
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

class _CopyTargetTile extends StatelessWidget {
  const _CopyTargetTile({
    required this.label,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: AppSizes.icon20,
              color: selected ? AppColors.primaryGreen : AppColors.textTertiary,
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: AppTypography.fontSize10,
                        color: _kAccent.withValues(alpha: 0.9),
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
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.submitting,
    required this.onSave,
    this.enabled = true,
  });

  final String label;
  final bool submitting;
  final VoidCallback onSave;
  final bool enabled;

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
          onPressed: submitting || !enabled ? null : onSave,
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
