import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/utils/time_converter.dart';
import '../../../dashboard/models/meal_plan_model.dart';
import '../../../dashboard/providers/meal_plan_provider.dart';
import '../../models/delivery_slot_model.dart';
import '../../providers/delivery_slot_list_provider.dart';
import '../../providers/subscription_detail_provider.dart';

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

class MySubscriptionScreen extends ConsumerStatefulWidget {
  const MySubscriptionScreen({
    super.key,
    this.planName = 'Your Plan',
    this.subscriptionId = '',
  });

  /// Shown in the header subtitle. Optional — defaults to a neutral label.
  final String planName;

  /// Active subscription id — enables the Invoice action and real event
  /// history. When empty, the Journey tab shows the placeholder timeline.
  final String subscriptionId;

  @override
  ConsumerState<MySubscriptionScreen> createState() =>
      _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends ConsumerState<MySubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Drives both the Diet Chart and Plan Manager tabs (shared provider).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mealPlanProvider.notifier).loadMealPlan();
    });
  }

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
              _Header(
                  planName: widget.planName,
                  subscriptionId: widget.subscriptionId),
              const _Tabs(),
              Expanded(
                child: TabBarView(
                  children: [
                    _JourneyTab(subscriptionId: widget.subscriptionId),
                    const _DietChartTab(),
                    const _PlanManagerTab(),
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
  const _Header({required this.planName, required this.subscriptionId});

  final String planName;
  final String subscriptionId;

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
          if (subscriptionId.isNotEmpty)
            _InvoiceButton(subscriptionId: subscriptionId),
        ],
      ),
    );
  }
}

/// Header action that fetches + opens the subscription invoice on demand.
class _InvoiceButton extends ConsumerStatefulWidget {
  const _InvoiceButton({required this.subscriptionId});

  final String subscriptionId;

  @override
  ConsumerState<_InvoiceButton> createState() => _InvoiceButtonState();
}

class _InvoiceButtonState extends ConsumerState<_InvoiceButton> {
  bool _loading = false;

  Future<void> _openInvoice() async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ref
          .read(subscriptionRepositoryProvider)
          .getInvoice(widget.subscriptionId);
      if (!mounted) return;
      setState(() => _loading = false);

      // Prefer a direct invoice URL when the backend provides one.
      final url = _firstUrl(data);
      if (url != null) {
        final launched =
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Could not open the invoice.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else if (mounted) {
        _showInvoiceSheet(data);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not load the invoice. Please try again.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String? _firstUrl(Map<String, dynamic> data) {
    for (final key in ['url', 'invoiceUrl', 'pdfUrl', 'invoicePdf', 'link']) {
      final v = data[key];
      if (v is String && v.startsWith('http')) return v;
    }
    return null;
  }

  void _showInvoiceSheet(Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invoice',
                style: TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing12),
              for (final entry in data.entries)
                if (entry.value is! Map && entry.value is! List)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize13,
                            color: AppColors.textSecondary,
                            fontFamily: 'Lato',
                          ),
                        ),
                        const SizedBox(width: AppSizes.spacing12),
                        Flexible(
                          child: Text(
                            '${entry.value}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: AppTypography.fontSize13,
                              fontWeight: AppTypography.semiBold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Lato',
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
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openInvoice,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        child: _loading
            ? const SizedBox(
                width: AppSizes.icon20,
                height: AppSizes.icon20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryGreen),
              )
            : const Icon(Icons.receipt_long_rounded,
                color: AppColors.primaryGreen, size: AppSizes.icon20),
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

  /// Defensively maps an open-ended backend event map onto the timeline model.
  factory _JourneyEvent.fromMap(Map<String, dynamic> m) {
    String? str(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is num) return v.toString();
      }
      return null;
    }

    final type = (str(['type', 'event', 'eventType', 'kind']) ?? '').toLowerCase();
    _EventKind kind;
    if (type.contains('counsel') || type.contains('call')) {
      kind = _EventKind.counselling;
    } else if (type.contains('renew')) {
      kind = _EventKind.renewal;
    } else if (type.contains('start') || type.contains('activate')) {
      kind = _EventKind.journeyStart;
    } else {
      kind = _EventKind.meals;
    }

    final rawDate = str(['date', 'createdAt', 'timestamp', 'eventDate', 'at']);

    return _JourneyEvent(
      kind: kind,
      title: str(['title', 'label', 'name', 'type', 'event']) ?? 'Update',
      date: rawDate != null ? convertMongoUtcToIst(rawDate) : '',
      subtitle: str(['description', 'message', 'note', 'detail']),
      status: str(['status']),
      hasMeetLink: (m['meetLink'] ?? m['meetingLink'] ?? m['link']) != null ||
          kind == _EventKind.counselling && (m['meetLink'] != null),
    );
  }
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

class _JourneyTab extends ConsumerWidget {
  const _JourneyTab({required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No id (e.g. opened without an active sub) → keep the placeholder timeline.
    if (subscriptionId.isEmpty) {
      return _timeline(_kJourneyEvents);
    }

    final historyAsync = ref.watch(subscriptionHistoryProvider(subscriptionId));
    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
      error: (_, __) => _timeline(_kJourneyEvents),
      data: (events) {
        if (events.isEmpty) return _timeline(const []);
        final mapped =
            events.map(_JourneyEvent.fromMap).toList(growable: false);
        return _timeline(mapped);
      },
    );
  }

  Widget _timeline(List<_JourneyEvent> events) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing16,
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing32,
      ),
      // +1 leading slot for the cancellation-policy banner.
      itemCount: events.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const _CancellationPolicyBanner();
        final i = index - 1;
        return _TimelineTile(
          event: events[i],
          isFirst: i == 0,
          isLast: i == events.length - 1,
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

// ─── Shared date helpers ──────────────────────────────────────────────────────

const _kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _kMonthLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Category → icon/colour, used by both diet meals and (loosely) elsewhere.
({IconData icon, Color color}) _categoryVisual(String category) {
  switch (category.toLowerCase()) {
    case 'lunch':
      return (icon: Icons.lunch_dining_rounded, color: _kAccent);
    case 'dinner':
      return (icon: Icons.dinner_dining_rounded, color: const Color(0xFF6A1B9A));
    case 'snacks':
    case 'snack':
      return (icon: Icons.bakery_dining_rounded, color: const Color(0xFF1976D2));
    default: // breakfast / anything else
      return (
        icon: Icons.free_breakfast_rounded,
        color: AppColors.primaryGreen
      );
  }
}

/// Priority used to order the meals of a day (Breakfast → Lunch → Dinner → …).
int _categoryOrder(String category) {
  switch (category.toLowerCase()) {
    case 'breakfast':
      return 0;
    case 'lunch':
      return 1;
    case 'snacks':
    case 'snack':
      return 2;
    case 'dinner':
      return 3;
    default:
      return 4;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — Diet chart (assigned meal plan, date-wise)
// ═══════════════════════════════════════════════════════════════════════════

class _DietChartTab extends ConsumerStatefulWidget {
  const _DietChartTab();

  @override
  ConsumerState<_DietChartTab> createState() => _DietChartTabState();
}

class _DietChartTabState extends ConsumerState<_DietChartTab>
    with AutomaticKeepAliveClientMixin {
  DateTime? _selectedDate;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(mealPlanProvider);

    if (state.isLoading && state.mealPlan == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (state.error != null && state.mealPlan == null) {
      return _CenterMessage(
        icon: Icons.error_outline_rounded,
        message: state.error!,
        onRetry: () => ref.read(mealPlanProvider.notifier).refresh(),
      );
    }

    // Only days that actually carry meals.
    final days = (state.mealPlan?.days ?? const <MealPlanDay>[])
        .where((d) => d.meals.any((m) => m.dishes.isNotEmpty))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (days.isEmpty) {
      return const _CenterMessage(
        icon: Icons.restaurant_menu_rounded,
        message: 'No meals have been assigned to your plan yet.',
      );
    }

    // Resolve the selected day (default to the first available).
    final selectedDate = _selectedDate != null &&
            days.any((d) => _dateOnly(d.date) == _selectedDate)
        ? _selectedDate!
        : _dateOnly(days.first.date);
    final selectedDay =
        days.firstWhere((d) => _dateOnly(d.date) == selectedDate);

    final meals = selectedDay.meals.where((m) => m.dishes.isNotEmpty).toList()
      ..sort((a, b) =>
          _categoryOrder(a.category.dishCategory)
              .compareTo(_categoryOrder(b.category.dishCategory)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Date selector ──
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPaddingHorizontal, AppSizes.spacing8,
                AppSizes.screenPaddingHorizontal, AppSizes.spacing8),
            itemCount: days.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSizes.spacing8),
            itemBuilder: (_, i) {
              final date = _dateOnly(days[i].date);
              final selected = date == selectedDate;
              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryGreen
                          : AppColors.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _kWeekdayShort[date.weekday - 1],
                        style: TextStyle(
                          fontSize: AppTypography.fontSize10,
                          fontWeight: AppTypography.semiBold,
                          color: selected
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize15,
                          fontWeight: AppTypography.bold,
                          color: selected ? Colors.white : AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // ── Meals for the selected day ──
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPaddingHorizontal, AppSizes.spacing8,
                AppSizes.screenPaddingHorizontal, AppSizes.spacing32),
            itemCount: meals.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSizes.spacing16),
            itemBuilder: (_, i) => _MealSection(meal: meals[i]),
          ),
        ),
      ],
    );
  }
}

/// A meal category (Breakfast / Lunch / …) header + its dish cards.
class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal});

  final MealPlanMeal meal;

  @override
  Widget build(BuildContext context) {
    final v = _categoryVisual(meal.category.dishCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: v.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: Icon(v.icon, color: v.color, size: AppSizes.icon18),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Text(
              meal.category.dishCategory.isEmpty
                  ? 'Meal'
                  : meal.category.dishCategory,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.bold,
                color: v.color,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing8),
        for (final dish in meal.dishes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
            child: _DishCard(dish: dish),
          ),
      ],
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish});

  final MealPlanDish dish;

  @override
  Widget build(BuildContext context) {
    final n = dish.nutrition;
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VegIndicator(isVeg: dish.isVeg),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: Text(
                  dish.dishName,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
              if (n.kcal > 0)
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        size: 14, color: AppColors.primaryGreen),
                    const SizedBox(width: 2),
                    Text(
                      '${n.kcal.toStringAsFixed(0)} kcal',
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
          if (n.protein > 0 || n.carbs > 0 || n.fat > 0) ...[
            const SizedBox(height: AppSizes.spacing8),
            Wrap(
              spacing: AppSizes.spacing6,
              runSpacing: AppSizes.spacing4,
              children: [
                if (n.protein > 0)
                  _MacroChip('P', n.protein, const Color(0xFF4A7C3E)),
                if (n.carbs > 0)
                  _MacroChip('C', n.carbs, const Color(0xFFC66301)),
                if (n.fat > 0) _MacroChip('F', n.fat, const Color(0xFF6BA84F)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VegIndicator extends StatelessWidget {
  const _VegIndicator({required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? const Color(0xFF388E3C) : const Color(0xFFD32F2F);
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.4)),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}g',
        style: TextStyle(
          fontSize: AppTypography.fontSize10,
          fontWeight: AppTypography.semiBold,
          color: color,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — Plan Manager (calendar of plan dates + slot picker)
// ═══════════════════════════════════════════════════════════════════════════

class _PlanManagerTab extends ConsumerStatefulWidget {
  const _PlanManagerTab();

  @override
  ConsumerState<_PlanManagerTab> createState() => _PlanManagerTabState();
}

class _PlanManagerTabState extends ConsumerState<_PlanManagerTab>
    with AutomaticKeepAliveClientMixin {
  // Chosen delivery slot per plan date, keyed by meal category (dishCategory).
  // e.g. _slotsByDate[Jun 12] = { 'Breakfast': morningSlot, 'Dinner': nightSlot }
  final Map<DateTime, Map<String, DeliverySlotApiModel>> _slotsByDate = {};

  @override
  bool get wantKeepAlive => true;

  /// Distinct meal categories assigned to [date] in the plan, ordered
  /// Breakfast → Lunch → Snacks → Dinner.
  List<String> _categoriesForDate(DateTime date) {
    final day = ref.read(mealPlanProvider).mealPlan?.dayForDate(date);
    return <String>{
      for (final m in day?.meals ?? const <MealPlanMeal>[])
        if (m.dishes.isNotEmpty) m.category.dishCategory,
    }.toList()
      ..sort((a, b) => _categoryOrder(a).compareTo(_categoryOrder(b)));
  }

  Future<void> _openSlotPicker(DateTime date) async {
    final key = _dateOnly(date);
    final categories = _categoriesForDate(key);
    if (categories.isEmpty) return;

    final picked =
        await showModalBottomSheet<Map<String, DeliverySlotApiModel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SlotPickerSheet(
        date: key,
        categories: categories,
        current: _slotsByDate[key] ?? const {},
      ),
    );
    if (picked != null && mounted) {
      setState(() => _slotsByDate[key] = picked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Delivery slots updated for ${key.day} ${_kMonthLong[key.month - 1]}.'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(mealPlanProvider);

    if (state.isLoading && state.mealPlan == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (state.error != null && state.mealPlan == null) {
      return _CenterMessage(
        icon: Icons.error_outline_rounded,
        message: state.error!,
        onRetry: () => ref.read(mealPlanProvider.notifier).refresh(),
      );
    }

    // Active (meal-assigned) dates → how many meal categories each carries.
    final categoryCountByDate = <DateTime, int>{};
    for (final d in state.mealPlan?.days ?? const <MealPlanDay>[]) {
      final categories = <String>{
        for (final m in d.meals)
          if (m.dishes.isNotEmpty) m.category.dishCategory,
      };
      if (categories.isNotEmpty) {
        categoryCountByDate[_dateOnly(d.date)] = categories.length;
      }
    }

    if (categoryCountByDate.isEmpty) {
      return const _CenterMessage(
        icon: Icons.event_busy_rounded,
        message: 'No scheduled meal dates yet.',
      );
    }

    // Per-date completion: how many of its categories already have a slot.
    final status = <DateTime, ({int chosen, int total})>{
      for (final e in categoryCountByDate.entries)
        e.key: (chosen: _slotsByDate[e.key]?.length ?? 0, total: e.value),
    };

    // Distinct months spanning the plan, in order.
    final months = (categoryCountByDate.keys
            .map((d) => DateTime(d.year, d.month))
            .toSet()
            .toList())
      ..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPaddingHorizontal, AppSizes.spacing16,
          AppSizes.screenPaddingHorizontal, AppSizes.spacing32),
      children: [
        const Text(
          'Delivery schedule',
          style: TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Tap a highlighted date to choose its delivery slot.',
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing16),
        for (final m in months)
          _MonthCalendar(
            month: m,
            status: status,
            onTapDate: _openSlotPicker,
          ),
        const SizedBox(height: AppSizes.spacing8),
        const _CalendarLegend(),
      ],
    );
  }
}

/// A single-month grid. Active (meal-assigned) dates are colourful + tappable;
/// dates with a chosen slot show a check.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.status,
    required this.onTapDate,
  });

  final DateTime month; // year + month (day ignored)

  /// Active dates → (chosen slots, total meal categories) for that date.
  final Map<DateTime, ({int chosen, int total})> status;
  final ValueChanged<DateTime> onTapDate;

  Widget _cell(DateTime date) {
    final st = status[date];
    return _DayCell(
      date: date,
      active: st != null,
      complete: st != null && st.chosen >= st.total,
      partial: st != null && st.chosen > 0 && st.chosen < st.total,
      onTap: onTapDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // Mon=1 → 0 blanks

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _cell(DateTime(month.year, month.month, day)),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacing16),
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${_kMonthLong[month.month - 1]} ${month.year}',
            style: const TextStyle(
              fontSize: AppTypography.fontSize16,
              fontWeight: AppTypography.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          Row(
            children: [
              for (final w in _kWeekdayShort)
                Expanded(
                  child: Center(
                    child: Text(
                      w.substring(0, 1),
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSizes.spacing6,
            crossAxisSpacing: AppSizes.spacing6,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.active,
    required this.complete,
    required this.partial,
    required this.onTap,
  });

  final DateTime date;
  final bool active;
  final bool complete; // every category for this date has a slot
  final bool partial; // some (not all) categories have a slot
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: AppTypography.fontSize13,
            color: AppColors.textTertiary.withValues(alpha: 0.6),
            fontFamily: 'Lato',
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => onTap(date),
      child: Container(
        decoration: BoxDecoration(
          gradient: complete
              ? const LinearGradient(
                  colors: [Color(0xFF5D9E40), Color(0xFF7AB655)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color:
              complete ? null : AppColors.primaryGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: partial
                ? _kAccent
                : AppColors.primaryGreen.withValues(alpha: complete ? 0 : 0.5),
            width: partial ? 1.5 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: AppTypography.fontSize13,
                fontWeight: AppTypography.bold,
                color: complete ? Colors.white : AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
            if (complete)
              const Positioned(
                bottom: 3,
                child: Icon(Icons.check_circle_rounded,
                    size: 9, color: Colors.white),
              )
            else if (partial)
              const Positioned(
                bottom: 3,
                child: Icon(Icons.more_horiz_rounded, size: 9, color: _kAccent),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    Widget swatch({Color? color, bool gradient = false, Color? border}) =>
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: gradient ? null : color,
            gradient: gradient
                ? const LinearGradient(
                    colors: [Color(0xFF5D9E40), Color(0xFF7AB655)])
                : null,
            border: border != null ? Border.all(color: border, width: 1.5) : null,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    Widget item(Widget s, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            s,
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato')),
          ],
        );
    return Wrap(
      spacing: AppSizes.spacing16,
      runSpacing: AppSizes.spacing8,
      children: [
        item(swatch(color: AppColors.primaryGreen.withValues(alpha: 0.18)),
            'Meal day'),
        item(
            swatch(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                border: _kAccent),
            'Partly set'),
        item(swatch(gradient: true), 'All set'),
      ],
    );
  }
}

/// Bottom sheet to pick a delivery slot for *each* meal category on a date.
///
/// The categories (e.g. Breakfast, Lunch, Dinner) come from the meal plan;
/// the selectable slots come from `/api/delivery-slot/list`. Each category is
/// an independent single-select, and the sheet returns a category→slot map.
class _SlotPickerSheet extends ConsumerStatefulWidget {
  const _SlotPickerSheet({
    required this.date,
    required this.categories,
    required this.current,
  });

  final DateTime date;
  final List<String> categories;
  final Map<String, DeliverySlotApiModel> current;

  @override
  ConsumerState<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends ConsumerState<_SlotPickerSheet> {
  // category → chosen slot id
  late final Map<String, String> _selectedByCategory = {
    for (final e in widget.current.entries) e.key: e.value.id,
  };

  bool get _allChosen =>
      widget.categories.every((c) => _selectedByCategory[c] != null);

  void _confirm(List<DeliverySlotApiModel> slots) {
    final byId = {for (final s in slots) s.id: s};
    final result = <String, DeliverySlotApiModel>{
      for (final c in widget.categories)
        if (byId[_selectedByCategory[c]] != null)
          c: byId[_selectedByCategory[c]]!,
    };
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(deliverySlotListProvider);
    final dateLabel =
        '${_kWeekdayShort[widget.date.weekday - 1]}, ${widget.date.day} ${_kMonthLong[widget.date.month - 1]}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  const Icon(Icons.local_shipping_rounded,
                      color: AppColors.primaryGreen, size: AppSizes.icon20),
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose delivery slots',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize18,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: AppTypography.fontSize12,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
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
              child: slotsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryGreen)),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(AppSizes.spacing24),
                  child: _CenterMessage(
                    icon: Icons.error_outline_rounded,
                    message: 'Could not load delivery slots.',
                    onRetry: () => ref.invalidate(deliverySlotListProvider),
                  ),
                ),
                data: (slots) {
                  if (slots.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSizes.spacing24),
                      child: Text('No delivery slots available.',
                          style: TextStyle(fontFamily: 'Lato')),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    itemCount: widget.categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.spacing20),
                    itemBuilder: (_, i) {
                      final category = widget.categories[i];
                      return _CategorySlotSection(
                        category: category,
                        slots: slots,
                        selectedId: _selectedByCategory[category],
                        onSelect: (id) => setState(
                            () => _selectedByCategory[category] = id),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: !_allChosen
                      ? null
                      : () => _confirm(
                          ref.read(deliverySlotListProvider).valueOrNull ??
                              const []),
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
                    _allChosen ? 'Confirm slots' : 'Select a slot for each meal',
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

/// One meal-category block inside the slot picker: a header (icon + name) and
/// the list of delivery slots, single-select within the block.
class _CategorySlotSection extends StatelessWidget {
  const _CategorySlotSection({
    required this.category,
    required this.slots,
    required this.selectedId,
    required this.onSelect,
  });

  final String category;
  final List<DeliverySlotApiModel> slots;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final visual = _categoryVisual(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child:
                  Icon(visual.icon, size: AppSizes.icon16, color: visual.color),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Text(
              category,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const Spacer(),
            if (selectedId == null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAccentBg,
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize10,
                    fontWeight: AppTypography.semiBold,
                    color: _kAccent,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing8),
        for (final slot in slots)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
            child: _SlotOptionTile(
              slot: slot,
              selected: slot.id == selectedId,
              accent: visual.color,
              onTap: () => onSelect(slot.id),
            ),
          ),
      ],
    );
  }
}

/// A single selectable delivery-slot row.
class _SlotOptionTile extends StatelessWidget {
  const _SlotOptionTile({
    required this.slot,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final DeliverySlotApiModel slot;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color:
                selected ? accent : AppColors.borderColor.withValues(alpha: 0.6),
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
              color: selected ? accent : AppColors.textTertiary,
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.slotName,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    slot.timeRange,
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
      ),
    );
  }
}

// ─── Shared centred message (loading-failure / empty) ─────────────────────────

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
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
              const SizedBox(height: AppSizes.spacing16),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                ),
                child: const Text('Retry', style: TextStyle(fontFamily: 'Lato')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
