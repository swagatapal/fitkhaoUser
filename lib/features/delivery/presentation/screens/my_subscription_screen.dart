import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// My Subscription — opened by tapping the active-plan banner.
//
// Three tabs:
//   1. Journey      → counselling + meal-delivery timeline
//   2. Diet Chart   → weekly diet plan (day selector + meals)
//   3. Plan Manager → delivery time-slot preferences
//
// DESIGN ONLY — all data here is placeholder. API wiring comes later, so the
// per-tab mock data lives in clearly-marked constants that a provider can
// replace without touching the widgets.
//
// Performance: each tab is its own widget, and the two interactive tabs keep
// their state alive (AutomaticKeepAlive) so switching tabs never rebuilds or
// resets the others. A slot/day tap rebuilds only that tab's subtree.
// ─────────────────────────────────────────────────────────────────────────────

const Color _kAccent = Color(0xFFC66301);
const Color _kAccentBg = Color(0xFFFFF8E1);

class MySubscriptionScreen extends StatelessWidget {
  const MySubscriptionScreen({super.key, this.planName = 'Your Plan'});

  /// Shown in the header subtitle. Optional — defaults to a neutral label.
  final String planName;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(planName: planName),
              const _Tabs(),
              const Expanded(
                child: TabBarView(
                  children: [
                    _JourneyTab(),
                    _DietChartTab(),
                    _PlanManagerTab(),
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

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.planName});

  final String planName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p20,
        vertical: AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: AppSizes.shadowBlur10,
            offset: const Offset(0, AppSizes.spacing2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.spacing8),
              decoration: BoxDecoration(
                color: AppColors.darkGreen,
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.textWhite, size: AppSizes.icon24),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Subscription',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
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
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const TabBar(
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primaryGreen,
        indicatorWeight: 2.5,
        labelStyle: TextStyle(
          fontSize: AppTypography.fontSize13,
          fontWeight: AppTypography.bold,
          fontFamily: 'Lato',
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: AppTypography.fontSize13,
          fontWeight: AppTypography.semiBold,
          fontFamily: 'Lato',
        ),
        tabs: [
          Tab(text: 'Journey'),
          Tab(text: 'Diet Chart'),
          Tab(text: 'Plan Manager'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — Journey
// ═══════════════════════════════════════════════════════════════════════════

enum _EventKind { counselling, journeyStart, meals, renewal }

class _JourneyEvent {
  final _EventKind kind;
  final String title;
  final String date;
  final String? subtitle;

  /// e.g. "Pending", "Scheduled", "No response" — rendered as a status chip.
  final String? status;

  /// When true a "Join meet" action is shown (counselling calls).
  final bool hasMeetLink;

  const _JourneyEvent({
    required this.kind,
    required this.title,
    required this.date,
    this.subtitle,
    this.status,
    this.hasMeetLink = false,
  });
}

// Placeholder timeline — replace with API data later.
const List<_JourneyEvent> _kJourneyEvents = [
  _JourneyEvent(
    kind: _EventKind.counselling,
    title: 'Counselling call being scheduled',
    date: 'Within 1–2 business days',
    subtitle:
        'Expect a call from customer support to schedule your counselling.',
    status: 'Pending',
  ),
  _JourneyEvent(
    kind: _EventKind.counselling,
    title: 'Counselling call scheduled',
    date: '16 Jun, 8:00 PM',
    subtitle: 'Your nutritionist will call you on the meeting link.',
    status: 'Scheduled',
    hasMeetLink: true,
  ),
  _JourneyEvent(
    kind: _EventKind.journeyStart,
    title: 'Your healthy journey begins',
    date: '20 Jun',
    subtitle: 'Transformative lifestyle starts today. Let’s go! 🎉',
  ),
  _JourneyEvent(
    kind: _EventKind.meals,
    title: '3 meals delivered',
    date: '20 Jun',
  ),
  _JourneyEvent(
    kind: _EventKind.meals,
    title: '3 meals delivered',
    date: '21 Jun',
  ),
  _JourneyEvent(
    kind: _EventKind.meals,
    title: '2 meals delivered',
    date: '22 Jun',
    subtitle: 'Lunch cancelled',
  ),
  _JourneyEvent(
    kind: _EventKind.counselling,
    title: 'Next counselling schedule call',
    date: '2 Jul',
    subtitle: 'For members on the 30-day plan.',
    status: 'No response',
  ),
  _JourneyEvent(
    kind: _EventKind.meals,
    title: '3 meals delivered',
    date: '3 Jul',
  ),
  _JourneyEvent(
    kind: _EventKind.counselling,
    title: 'Counselling call scheduled',
    date: '4 Jul, 8:00 PM',
    subtitle: 'Review your progress with your nutritionist.',
    status: 'Scheduled',
    hasMeetLink: true,
  ),
  _JourneyEvent(
    kind: _EventKind.renewal,
    title: 'Plan renewal',
    date: '19 Jul',
    subtitle: 'Renew to keep your meals and counselling going.',
  ),
];

class _JourneyTab extends StatelessWidget {
  const _JourneyTab();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing16,
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing32,
      ),
      // +1 leading slot for the cancellation-policy banner.
      itemCount: _kJourneyEvents.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const _CancellationPolicyBanner();
        final i = index - 1;
        return _TimelineTile(
          event: _kJourneyEvents[i],
          isFirst: i == 0,
          isLast: i == _kJourneyEvents.length - 1,
        );
      },
    );
  }
}

class _CancellationPolicyBanner extends StatelessWidget {
  const _CancellationPolicyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacing16),
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: _kAccentBg,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: AppSizes.icon18, color: _kAccent),
          SizedBox(width: AppSizes.spacing10),
          Expanded(
            child: Text(
              'You can only cancel orders before 8:00 PM for the next day.',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                color: Color(0xFF795548),
                height: 1.4,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One timeline row: a node + connecting rails on the left, a content card on
/// the right. Visuals (icon/colour) are derived from the event kind.
class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final _JourneyEvent event;
  final bool isFirst;
  final bool isLast;

  ({IconData icon, Color color}) get _visual {
    switch (event.kind) {
      case _EventKind.counselling:
        return (icon: Icons.headset_mic_rounded, color: const Color(0xFF2E7CF6));
      case _EventKind.journeyStart:
        return (icon: Icons.flag_rounded, color: AppColors.primaryGreen);
      case _EventKind.meals:
        return (icon: Icons.restaurant_rounded, color: AppColors.primaryGreen);
      case _EventKind.renewal:
        return (icon: Icons.autorenew_rounded, color: _kAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _visual;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Rail + node ──
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: AppSizes.spacing8,
                  color: isFirst
                      ? Colors.transparent
                      : AppColors.borderColor.withValues(alpha: 0.6),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: v.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: v.color.withValues(alpha: 0.5)),
                  ),
                  child: Icon(v.icon, size: 16, color: v.color),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : AppColors.borderColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          // ── Content card ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
              child: Container(
                padding: const EdgeInsets.all(AppSizes.spacing12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radius12),
                  border: Border.all(
                      color: AppColors.borderColor.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: AppTypography.fontSize14,
                              fontWeight: AppTypography.bold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ),
                        if (event.status != null) _StatusChip(label: event.status!),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.date,
                      style: TextStyle(
                        fontSize: AppTypography.fontSize10,
                        fontWeight: AppTypography.semiBold,
                        color: v.color,
                        fontFamily: 'Lato',
                      ),
                    ),
                    if (event.subtitle != null) ...[
                      const SizedBox(height: AppSizes.spacing6),
                      Text(
                        event.subtitle!,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                          height: 1.35,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                    if (event.hasMeetLink) ...[
                      const SizedBox(height: AppSizes.spacing10),
                      _MeetLinkButton(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  Color get _color {
    switch (label.toLowerCase()) {
      case 'scheduled':
        return AppColors.primaryGreen;
      case 'pending':
        return _kAccent;
      case 'no response':
        return AppColors.errorColor;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: AppTypography.bold,
          color: c,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}

class _MeetLinkButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Wired to the actual meet URL during API integration.
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing12,
          vertical: AppSizes.spacing6,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border:
              Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_rounded,
                size: 16, color: AppColors.primaryGreen),
            SizedBox(width: AppSizes.spacing6),
            Text(
              'Join meeting',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                fontWeight: AppTypography.semiBold,
                color: AppColors.primaryGreen,
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
// TAB 2 — Weekly diet chart
// ═══════════════════════════════════════════════════════════════════════════

class _DietMeal {
  final String type; // Breakfast / Lunch / Dinner
  final String dish;
  final String kcal;
  const _DietMeal(this.type, this.dish, this.kcal);
}

const List<String> _kDays = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
];

// Placeholder weekly chart — one list of meals per weekday.
const List<List<_DietMeal>> _kWeeklyChart = [
  [
    _DietMeal('Breakfast', 'Veg poha + sprouts', '320 kcal'),
    _DietMeal('Lunch', 'Grilled paneer bowl', '480 kcal'),
    _DietMeal('Dinner', 'Moong dal + veggies', '410 kcal'),
  ],
  [
    _DietMeal('Breakfast', 'Oats with fruits', '300 kcal'),
    _DietMeal('Lunch', 'Rajma rice bowl', '520 kcal'),
    _DietMeal('Dinner', 'Grilled chicken salad', '430 kcal'),
  ],
  [
    _DietMeal('Breakfast', 'Besan chilla', '310 kcal'),
    _DietMeal('Lunch', 'Quinoa veg pulao', '470 kcal'),
    _DietMeal('Dinner', 'Mixed veg curry + roti', '400 kcal'),
  ],
  [
    _DietMeal('Breakfast', 'Idli + sambar', '330 kcal'),
    _DietMeal('Lunch', 'Egg bhurji bowl', '490 kcal'),
    _DietMeal('Dinner', 'Tofu stir fry', '420 kcal'),
  ],
  [
    _DietMeal('Breakfast', 'Smoothie bowl', '290 kcal'),
    _DietMeal('Lunch', 'Chickpea salad bowl', '460 kcal'),
    _DietMeal('Dinner', 'Veg khichdi', '390 kcal'),
  ],
  [
    _DietMeal('Breakfast', 'Vegetable upma', '300 kcal'),
    _DietMeal('Lunch', 'Fish curry + rice', '540 kcal'),
    _DietMeal('Dinner', 'Paneer tikka + salad', '440 kcal'),
  ],
  [
    _DietMeal('Breakfast', 'Stuffed paratha (low oil)', '350 kcal'),
    _DietMeal('Lunch', 'Soya chunk curry bowl', '500 kcal'),
    _DietMeal('Dinner', 'Clear veg soup + toast', '360 kcal'),
  ],
];

class _DietChartTab extends StatefulWidget {
  const _DietChartTab();

  @override
  State<_DietChartTab> createState() => _DietChartTabState();
}

class _DietChartTabState extends State<_DietChartTab>
    with AutomaticKeepAliveClientMixin {
  int _selectedDay = 0;

  @override
  bool get wantKeepAlive => true;

  ({IconData icon, Color color}) _mealVisual(String type) {
    switch (type) {
      case 'Lunch':
        return (icon: Icons.lunch_dining_rounded, color: _kAccent);
      case 'Dinner':
        return (icon: Icons.dinner_dining_rounded, color: const Color(0xFF6A1B9A));
      default:
        return (icon: Icons.free_breakfast_rounded, color: AppColors.primaryGreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final meals = _kWeeklyChart[_selectedDay];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day selector
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPaddingHorizontal, AppSizes.spacing16,
                AppSizes.screenPaddingHorizontal, AppSizes.spacing8),
            itemCount: _kDays.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSizes.spacing8),
            itemBuilder: (context, i) {
              final selected = i == _selectedDay;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radius12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryGreen
                          : AppColors.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _kDays[i],
                    style: TextStyle(
                      fontSize: AppTypography.fontSize13,
                      fontWeight: AppTypography.bold,
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPaddingHorizontal, AppSizes.spacing8,
                AppSizes.screenPaddingHorizontal, AppSizes.spacing32),
            itemCount: meals.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
            itemBuilder: (context, i) {
              final meal = meals[i];
              final v = _mealVisual(meal.type);
              return Container(
                padding: const EdgeInsets.all(AppSizes.spacing12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radius12),
                  border: Border.all(
                      color: AppColors.borderColor.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: v.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                      ),
                      child: Icon(v.icon, color: v.color, size: AppSizes.icon24),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.type,
                            style: TextStyle(
                              fontSize: AppTypography.fontSize10,
                              fontWeight: AppTypography.bold,
                              color: v.color,
                              fontFamily: 'Lato',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meal.dish,
                            style: const TextStyle(
                              fontSize: AppTypography.fontSize14,
                              fontWeight: AppTypography.semiBold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing8),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            size: 14, color: AppColors.primaryGreen),
                        const SizedBox(width: 2),
                        Text(
                          meal.kcal,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize12,
                            color: AppColors.textSecondary,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — Plan Manager (delivery time slots)
// ═══════════════════════════════════════════════════════════════════════════

class _SlotPeriod {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> slots;
  const _SlotPeriod(this.label, this.icon, this.color, this.slots);
}

const List<_SlotPeriod> _kSlotPeriods = [
  _SlotPeriod('Morning', Icons.wb_sunny_rounded, Color(0xFFF5A623),
      ['7:00 – 8:00 AM', '8:00 – 9:00 AM']),
  _SlotPeriod('Afternoon', Icons.wb_twilight_rounded, Color(0xFFC66301),
      ['12:00 – 1:00 PM', '1:00 – 2:00 PM']),
  _SlotPeriod('Night', Icons.nightlight_round, Color(0xFF3F51B5),
      ['8:00 – 9:00 PM', '9:00 – 10:00 PM']),
];

class _PlanManagerTab extends StatefulWidget {
  const _PlanManagerTab();

  @override
  State<_PlanManagerTab> createState() => _PlanManagerTabState();
}

class _PlanManagerTabState extends State<_PlanManagerTab>
    with AutomaticKeepAliveClientMixin {
  // One selected slot per period (keyed by period label).
  final Map<String, String> _selected = {};

  @override
  bool get wantKeepAlive => true;

  void _select(String period, String slot) {
    setState(() {
      // Tapping the selected slot again clears it.
      if (_selected[period] == slot) {
        _selected.remove(period);
      } else {
        _selected[period] = slot;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPaddingHorizontal, AppSizes.spacing16,
                AppSizes.screenPaddingHorizontal, AppSizes.spacing24),
            children: [
              const Text(
                'Delivery time slots',
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pick a preferred window for each part of the day.',
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing16),
              for (final period in _kSlotPeriods)
                _SlotPeriodCard(
                  period: period,
                  selected: _selected[period.label],
                  onSelect: (slot) => _select(period.label, slot),
                ),
            ],
          ),
        ),
        _SavePreferencesBar(
          enabled: _selected.isNotEmpty,
          onSave: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Slot preferences saved.'),
                backgroundColor: AppColors.primaryGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SlotPeriodCard extends StatelessWidget {
  const _SlotPeriodCard({
    required this.period,
    required this.selected,
    required this.onSelect,
  });

  final _SlotPeriod period;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(period.icon, size: AppSizes.icon20, color: period.color),
              const SizedBox(width: AppSizes.spacing8),
              Text(
                period.label,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          Row(
            children: [
              for (final slot in period.slots) ...[
                Expanded(
                  child: _SlotChip(
                    label: slot,
                    selected: slot == selected,
                    accent: period.color,
                    onTap: () => onSelect(slot),
                  ),
                ),
                if (slot != period.slots.last)
                  const SizedBox(width: AppSizes.spacing8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: selected ? accent : AppColors.borderColor.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              Icon(Icons.check_circle_rounded, size: 14, color: accent),
              const SizedBox(width: AppSizes.spacing6),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight:
                      selected ? AppTypography.bold : AppTypography.regular,
                  color: selected ? accent : AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavePreferencesBar extends StatelessWidget {
  const _SavePreferencesBar({required this.enabled, required this.onSave});

  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing12,
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing12,
        ),
        child: SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: ElevatedButton(
            onPressed: enabled ? onSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.borderColor.withValues(alpha: 0.6),
              disabledForegroundColor: AppColors.textSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
            ),
            child: const Text(
              'Save Preferences',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.bold,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
