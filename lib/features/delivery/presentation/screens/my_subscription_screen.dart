import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/time_converter.dart';
import '../../../consultation/presentation/screens/book_consultation_screen.dart';
import '../../../dashboard/models/meal_plan_model.dart';
import '../../../dashboard/providers/meal_plan_provider.dart';
import '../../models/delivery_slot_model.dart';
import '../../models/subscription_timeline_model.dart';
import '../../providers/confirmed_slots_provider.dart';
import '../../providers/delivery_slot_confirm_provider.dart';
import '../../providers/delivery_slot_list_provider.dart';
import '../../providers/selected_address_provider.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child:  DefaultTabController(
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
                      const _JourneyTab(),
                      const _DietChartTab(),
                      const _PlanManagerTab(),
                    ],
                  ),
                ),
              ],
            ),
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
        final launched = await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication);
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
// TAB 1 — Journey (subscription timeline: steps + daily meals)
// ═══════════════════════════════════════════════════════════════════════════

class _JourneyTab extends ConsumerWidget {
  const _JourneyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionTimelineProvider);
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
      error: (e, st) {
        debugPrint('[Journey] timeline error: $e\n$st');
        return _CenterMessage(
          icon: Icons.error_outline_rounded,
          message: 'Could not load your journey.\n$e',
          onRetry: () => ref.invalidate(subscriptionTimelineProvider),
        );
      },
      data: (timeline) => _TimelineContent(timeline: timeline),
    );
  }
}

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({required this.timeline});

  final SubscriptionTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final steps = timeline.steps;
    final days = timeline.dailyMeals;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing16,
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing32,
      ),
      children: [
        // const _CancellationPolicyBanner(),
        const _HealthProfileButton(),
        const SizedBox(height: AppSizes.spacing12),
        const _ConsultationSlotButton(),
        const SizedBox(height: AppSizes.spacing16),
        if (timeline.subscription != null)
          _TimelineSummaryCard(subscription: timeline.subscription!),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: AppSizes.spacing20),
          const _SectionHeader('Your journey'),
          const SizedBox(height: AppSizes.spacing12),
          for (var i = 0; i < steps.length; i++)
            _TimelineStepTile(
              step: steps[i],
              isFirst: i == 0,
              isLast: i == steps.length - 1,
            ),
        ],
        if (days.isNotEmpty) ...[
          const SizedBox(height: AppSizes.spacing20),
          const _SectionHeader('Daily meals'),
          const SizedBox(height: AppSizes.spacing12),
          for (final day in days) _DailyMealsCard(day: day),
        ],
        if (steps.isEmpty && days.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSizes.spacing32),
            child: _CenterMessage(
              icon: Icons.timeline_rounded,
              message: 'Your journey timeline will appear here.',
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: AppTypography.fontSize16,
        fontWeight: AppTypography.bold,
        color: AppColors.textPrimary,
        fontFamily: 'Lato',
      ),
    );
  }
}

/// Entry point to the user's detailed health profile, shown above the
/// subscription summary in the Journey tab.
class _HealthProfileButton extends StatelessWidget {
  const _HealthProfileButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        onTap: () => context.push(RouteNames.detailedHealthInfo),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.spacing12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3)),
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
                padding: const EdgeInsets.all(AppSizes.spacing8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                child: const Icon(Icons.monitor_heart_rounded,
                    color: AppColors.primaryGreen, size: AppSizes.icon20),
              ),
              const SizedBox(width: AppSizes.spacing12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health profile',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'View and update your health details',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primaryGreen, size: AppSizes.icon24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the consultation booking flow (pick nutritionist → slot → confirm).
class _ConsultationSlotButton extends StatelessWidget {
  const _ConsultationSlotButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BookConsultationScreen(),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.spacing12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
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
                padding: const EdgeInsets.all(AppSizes.spacing8),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                child: const Icon(Icons.event_available_rounded,
                    color: _kAccent, size: AppSizes.icon20),
              ),
              const SizedBox(width: AppSizes.spacing12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose consultation time slot',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Book a session with a nutritionist',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: _kAccent, size: AppSizes.icon24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient hero summarising the active subscription.
class _TimelineSummaryCard extends StatelessWidget {
  const _TimelineSummaryCard({required this.subscription});

  final TimelineSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final range = _dateRangeLabel(subscription.startDate, subscription.endDate);
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subscription.planName.isEmpty
                      ? 'Your Plan'
                      : subscription.planName,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize18,
                    fontWeight: AppTypography.bold,
                    color: Colors.white,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
              _StatusPill(subscription.status),
            ],
          ),
          if (range != null) ...[
            const SizedBox(height: AppSizes.spacing8),
            Row(
              children: [
                const Icon(Icons.date_range_rounded,
                    size: AppSizes.icon16, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  range,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: Colors.white70,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.spacing12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_bottom_rounded,
                    size: AppSizes.icon16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '${subscription.remainingDays} '
                  '${subscription.remainingDays == 1 ? 'day' : 'days'} remaining',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.bold,
                    color: Colors.white,
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

/// One journey step: a status-coloured node + rails on the left, a card right.
class _TimelineStepTile extends StatelessWidget {
  const _TimelineStepTile({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });

  final TimelineStep step;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final v = _timelineStatusVisual(step.status);
    final solid = step.status == TimelineStatus.completed ||
        step.status == TimelineStatus.active;
    final dateStr = step.date != null ? convertMongoUtcToIst(step.date!) : '';

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
                    color: solid ? v.color : v.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: v.color.withValues(alpha: solid ? 1 : 0.5)),
                  ),
                  child: Icon(v.icon,
                      size: 16, color: solid ? Colors.white : v.color),
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
                            step.name,
                            style: const TextStyle(
                              fontSize: AppTypography.fontSize14,
                              fontWeight: AppTypography.bold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ),
                        _TimelineStatusChip(step.status),
                      ],
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize10,
                          fontWeight: AppTypography.semiBold,
                          color: v.color,
                          fontFamily: 'Lato',
                        ),
                      ),
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

/// A day's confirmed/planned meals grouped under its date.
class _DailyMealsCard extends StatelessWidget {
  const _DailyMealsCard({required this.day});

  final TimelineDay day;

  @override
  Widget build(BuildContext context) {
    final label = _dayLabel(day.parsedDate) ?? day.date;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppColors.primaryGreen),
              const SizedBox(width: AppSizes.spacing8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize13,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          for (var i = 0; i < day.meals.length; i++) ...[
            if (i > 0)
              Divider(
                  height: AppSizes.spacing16,
                  color: AppColors.borderColor.withValues(alpha: 0.4)),
            _MealRow(meal: day.meals[i]),
          ],
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal});

  final TimelineMeal meal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          child: Icon(_slotIcon(meal.slot),
              size: AppSizes.icon16, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: AppSizes.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal.slot,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              if (meal.slotTime.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  meal.slotTime,
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
        _TimelineStatusChip(meal.status),
      ],
    );
  }
}

/// Status chip driven by [TimelineStatus] (hidden for unknown).
class _TimelineStatusChip extends StatelessWidget {
  const _TimelineStatusChip(this.status);

  final TimelineStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.label.isEmpty) return const SizedBox.shrink();
    final c = _timelineStatusVisual(status).color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: Text(
        status.label,
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

/// Translucent status pill for the (dark) summary card.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    final label = '${status[0].toUpperCase()}${status.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: AppTypography.bold,
          color: Colors.white,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}

/// Status → node icon + colour for the journey stepper.
({IconData icon, Color color}) _timelineStatusVisual(TimelineStatus s) {
  switch (s) {
    case TimelineStatus.completed:
      return (icon: Icons.check_rounded, color: AppColors.primaryGreen);
    case TimelineStatus.active:
      return (icon: Icons.play_arrow_rounded, color: const Color(0xFF2E7CF6));
    case TimelineStatus.pending:
      return (icon: Icons.hourglass_top_rounded, color: _kAccent);
    case TimelineStatus.upcoming:
      return (icon: Icons.schedule_rounded, color: AppColors.textSecondary);
    case TimelineStatus.rescheduled:
      return (icon: Icons.event_repeat_rounded, color: const Color(0xFF8E24AA));
    case TimelineStatus.cancelled:
      return (icon: Icons.close_rounded, color: AppColors.errorColor);
    case TimelineStatus.unknown:
      return (icon: Icons.circle_outlined, color: AppColors.textSecondary);
  }
}

IconData _slotIcon(String slot) {
  final s = slot.toLowerCase();
  if (s.contains('morning')) return Icons.wb_sunny_rounded;
  if (s.contains('afternoon')) return Icons.wb_twilight_rounded;
  if (s.contains('night') || s.contains('evening')) {
    return Icons.nightlight_round;
  }
  return Icons.local_shipping_rounded;
}

/// "Fri, 3 Jul" for a date-only value (null-safe).
String? _dayLabel(DateTime? d) {
  if (d == null) return null;
  return '${_kWeekdayShort[d.weekday - 1]}, ${d.day} ${_kMonthLong[d.month - 1].substring(0, 3)}';
}

/// "2 Jul – 13 Jul" from UTC start/end, shown in IST.
String? _dateRangeLabel(DateTime? start, DateTime? end) {
  DateTime ist(DateTime d) =>
      d.toUtc().add(const Duration(hours: 5, minutes: 30));
  String fmt(DateTime d) {
    final i = ist(d);
    return '${i.day} ${_kMonthLong[i.month - 1].substring(0, 3)}';
  }

  if (start == null && end == null) return null;
  if (start != null && end != null) return '${fmt(start)} – ${fmt(end)}';
  return fmt((start ?? end)!);
}

// ─── Shared date helpers ──────────────────────────────────────────────────────

const _kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _kMonthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `YYYY-MM-DD` in local time — the format the confirm API expects.
String _apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Category → icon/colour, used by both diet meals and (loosely) elsewhere.
({IconData icon, Color color}) _categoryVisual(String category) {
  switch (category.toLowerCase()) {
    case 'lunch':
      return (icon: Icons.lunch_dining_rounded, color: _kAccent);
    case 'dinner':
      return (
        icon: Icons.dinner_dining_rounded,
        color: const Color(0xFF6A1B9A)
      );
    case 'snacks':
    case 'snack':
      return (
        icon: Icons.bakery_dining_rounded,
        color: const Color(0xFF1976D2)
      );
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
      ..sort((a, b) => _categoryOrder(a.category.dishCategory)
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
                AppSizes.screenPaddingHorizontal,
                AppSizes.spacing8,
                AppSizes.screenPaddingHorizontal,
                AppSizes.spacing8),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
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
                          color:
                              selected ? Colors.white : AppColors.textPrimary,
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
                AppSizes.screenPaddingHorizontal,
                AppSizes.spacing8,
                AppSizes.screenPaddingHorizontal,
                AppSizes.spacing32),
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
  // Chosen delivery slot per plan date, keyed by meal-category id.
  // e.g. _slotsByDate[Jun 12] = { '<breakfastId>': morningSlot, '<dinnerId>': nightSlot }
  final Map<DateTime, Map<String, DeliverySlotApiModel>> _slotsByDate = {};

  @override
  bool get wantKeepAlive => true;

  /// Distinct meal categories assigned to [date] in the plan, deduped by id and
  /// ordered Breakfast → Lunch → Snacks → Dinner.
  List<MealCategory> _categoriesForDate(DateTime date) {
    final day = ref.read(mealPlanProvider).mealPlan?.dayForDate(date);
    final seen = <String>{};
    final result = <MealCategory>[];
    for (final m in day?.meals ?? const <MealPlanMeal>[]) {
      if (m.dishes.isEmpty) continue;
      if (seen.add(m.category.id)) result.add(m.category);
    }
    result.sort((a, b) => _categoryOrder(a.dishCategory)
        .compareTo(_categoryOrder(b.dishCategory)));
    return result;
  }

  /// Routes a date tap: already-confirmed dates open the read-only/cancel
  /// sheet; everything else opens the slot picker.
  Future<void> _openDate(DateTime date) async {
    final key = _dateOnly(date);
    final confirmed = ref.read(confirmedSlotsProvider).valueOrNull?[key];
    if (confirmed != null) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ConfirmedSlotsSheet(date: key),
      );
    } else {
      await _openSlotPicker(key);
    }
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

  /// Builds the batch payload from the local selections and submits it.
  Future<void> _confirmSchedule() async {
    final messenger = ScaffoldMessenger.of(context);
    final address = ref.read(selectedDeliveryAddressProvider);
    if (address == null || address.id.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Please select a delivery address first.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // One entry per date that has at least one slot chosen; within a date,
    // group the chosen categories under their slot.
    final dates = _slotsByDate.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList()
      ..sort();

    final deliveries = <ConfirmDeliveryDate>[];
    for (final date in dates) {
      final bySlot = <String, List<String>>{};
      _slotsByDate[date]!.forEach((categoryId, slot) {
        bySlot.putIfAbsent(slot.id, () => <String>[]).add(categoryId);
      });
      deliveries.add(ConfirmDeliveryDate(
        deliveryDate: _apiDate(date),
        slots: bySlot.entries
            .map((e) => ConfirmSlotItem(slotId: e.key, categoryIds: e.value))
            .toList(),
      ));
    }

    if (deliveries.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Choose at least one delivery slot to confirm.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final ok = await ref.read(deliverySlotConfirmProvider.notifier).submit(
          ConfirmDeliveryScheduleRequest(
            deliveryAddressId: address.id,
            deliveries: deliveries,
          ),
        );
    if (!mounted) return;
    if (ok) {
      // Submitted dates now live server-side; drop the local drafts and
      // re-sync the confirmed calendar.
      setState(() {
        for (final date in dates) {
          _slotsByDate.remove(date);
        }
      });
      ref.invalidate(confirmedSlotsProvider);
    }
    final message = ref.read(deliverySlotConfirmProvider).message;
    messenger.showSnackBar(SnackBar(
      content: Text(message ??
          (ok ? 'Delivery schedule confirmed.' : 'Could not confirm.')),
      backgroundColor: ok ? AppColors.primaryGreen : AppColors.errorColor,
      behavior: SnackBarBehavior.floating,
    ));
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
      final categoryIds = <String>{
        for (final m in d.meals)
          if (m.dishes.isNotEmpty) m.category.id,
      };
      if (categoryIds.isNotEmpty) {
        categoryCountByDate[_dateOnly(d.date)] = categoryIds.length;
      }
    }

    if (categoryCountByDate.isEmpty) {
      return const _CenterMessage(
        icon: Icons.event_busy_rounded,
        message: 'No scheduled meal dates yet.',
      );
    }

    // Slots already confirmed server-side (best-effort; absent while loading
    // or on error — the date simply isn't marked locked-in).
    final confirmedDates = (ref.watch(confirmedSlotsProvider).valueOrNull ??
            const <DateTime, ConfirmedSlotDay>{})
        .keys
        .where(categoryCountByDate.containsKey)
        .toSet();

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
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing16,
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing32),
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
          'Tap a date to pick its slots. Confirmed dates show a lock — tap to '
          'review or cancel.',
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        const _CouponHintBanner(),
        const SizedBox(height: AppSizes.spacing16),
        for (final m in months)
          _MonthCalendar(
            month: m,
            status: status,
            confirmedDates: confirmedDates,
            onTapDate: _openDate,
          ),
        const SizedBox(height: AppSizes.spacing8),
        const _CalendarLegend(),
        const SizedBox(height: AppSizes.spacing24),
        _buildConfirmButton(),
      ],
    );
  }

  /// Sticky-looking CTA that submits every not-yet-confirmed date with a slot.
  Widget _buildConfirmButton() {
    final confirmed = ref.watch(confirmedSlotsProvider).valueOrNull ??
        const <DateTime, ConfirmedSlotDay>{};
    final scheduledDays = _slotsByDate.entries
        .where((e) => e.value.isNotEmpty && !confirmed.containsKey(e.key))
        .length;
    final submitting =
        ref.watch(deliverySlotConfirmProvider.select((s) => s.isSubmitting));
    final enabled = scheduledDays > 0 && !submitting;

    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        onPressed: enabled ? _confirmSchedule : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderColor.withValues(alpha: 0.6),
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
                scheduledDays == 0
                    ? 'Choose slots to confirm'
                    : 'Confirm schedule · $scheduledDays ${scheduledDays == 1 ? 'day' : 'days'}',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.bold,
                  fontFamily: 'Lato',
                ),
              ),
      ),
    );
  }
}

/// A single-month grid. Active (meal-assigned) dates are colourful + tappable;
/// dates with a chosen slot show a check.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.status,
    required this.confirmedDates,
    required this.onTapDate,
  });

  final DateTime month; // year + month (day ignored)

  /// Active dates → (chosen slots, total meal categories) for that date.
  final Map<DateTime, ({int chosen, int total})> status;

  /// Dates whose slots are already confirmed server-side.
  final Set<DateTime> confirmedDates;
  final ValueChanged<DateTime> onTapDate;

  Widget _cell(DateTime date) {
    final st = status[date];
    return _DayCell(
      date: date,
      active: st != null,
      confirmed: confirmedDates.contains(date),
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
    required this.confirmed,
    required this.complete,
    required this.partial,
    required this.onTap,
  });

  final DateTime date;
  final bool active;
  final bool confirmed; // locked-in server-side (top priority)
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

    // Confirmed beats every local draft state.
    final filled = confirmed || complete;
    final whiteFg = confirmed || complete;

    return GestureDetector(
      onTap: () => onTap(date),
      child: Container(
        decoration: BoxDecoration(
          gradient: confirmed
              ? null
              : complete
                  ? const LinearGradient(
                      colors: [Color(0xFF5D9E40), Color(0xFF7AB655)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
          color: confirmed
              ? AppColors.darkGreen
              : complete
                  ? null
                  : AppColors.primaryGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: partial && !confirmed
                ? _kAccent
                : AppColors.primaryGreen.withValues(alpha: filled ? 0 : 0.5),
            width: partial && !confirmed ? 1.5 : 1,
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
                color: whiteFg ? Colors.white : AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
            if (confirmed)
              const Positioned(
                bottom: 3,
                child: Icon(Icons.lock_rounded, size: 9, color: Colors.white),
              )
            else if (complete)
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
            border:
                border != null ? Border.all(color: border, width: 1.5) : null,
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
        item(swatch(color: AppColors.darkGreen), 'Confirmed'),
      ],
    );
  }
}

/// Friendly nudge that confirming slots unlocks a coupon.
class _CouponHintBanner extends StatelessWidget {
  const _CouponHintBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing12, vertical: AppSizes.spacing12),
      decoration: BoxDecoration(
        color: _kAccentBg,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            child: const Icon(Icons.local_offer_rounded,
                color: _kAccent, size: AppSizes.icon20),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Earn a coupon!',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.bold,
                    color: _kAccent,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'If you cancel your order you will get a coupon on your next outlet order.',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize10,
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
  final List<MealCategory> categories;
  final Map<String, DeliverySlotApiModel> current; // categoryId → slot

  @override
  ConsumerState<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends ConsumerState<_SlotPickerSheet> {
  // categoryId → chosen slot id
  late final Map<String, String> _selectedByCategory = {
    for (final e in widget.current.entries) e.key: e.value.id,
  };

  bool get _allChosen =>
      widget.categories.every((c) => _selectedByCategory[c.id] != null);

  void _confirm(List<DeliverySlotApiModel> slots) {
    final byId = {for (final s in slots) s.id: s};
    final result = <String, DeliverySlotApiModel>{
      for (final c in widget.categories)
        if (byId[_selectedByCategory[c.id]] != null)
          c.id: byId[_selectedByCategory[c.id]]!,
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
                        selectedId: _selectedByCategory[category.id],
                        onSelect: (id) => setState(
                            () => _selectedByCategory[category.id] = id),
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
                    _allChosen
                        ? 'Confirm slots'
                        : 'Select a slot for each meal',
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

  final MealCategory category;
  final List<DeliverySlotApiModel> slots;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final visual = _categoryVisual(category.dishCategory);
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
              category.dishCategory,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            color: selected
                ? accent
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

/// Read-only view of a date's already-confirmed slots, with per-slot
/// cancellation (POST /api/orders/cancel/:orderId). Watches the confirmed-slots
/// provider so a successful cancel updates the list live.
class _ConfirmedSlotsSheet extends ConsumerStatefulWidget {
  const _ConfirmedSlotsSheet({required this.date});

  final DateTime date;

  @override
  ConsumerState<_ConfirmedSlotsSheet> createState() =>
      _ConfirmedSlotsSheetState();
}

class _ConfirmedSlotsSheetState extends ConsumerState<_ConfirmedSlotsSheet> {
  String? _cancellingOrderId;

  Future<void> _cancel(ConfirmedSlotEntry entry) async {
    if (entry.orderId.isEmpty) return;
    final reason = await _askReason(entry);
    if (reason == null || !mounted) return;

    setState(() => _cancellingOrderId = entry.orderId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref
          .read(orderRepositoryProvider)
          .cancelOrder(orderId: entry.orderId, reason: reason);
      if (!mounted) return;
      setState(() => _cancellingOrderId = null);
      final ok = res['success'] == true;
      if (ok) ref.invalidate(confirmedSlotsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? '${entry.slotName} slot cancelled.'
            : (res['message'] as String?) ?? 'Could not cancel this slot.'),
        backgroundColor: ok ? AppColors.primaryGreen : AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _cancellingOrderId = null);
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not cancel this slot. Please try again.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<String?> _askReason(ConfirmedSlotEntry entry) {
    final controller = TextEditingController(text: "Don't want this slot");
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel slot?',
            style:
                TextStyle(fontFamily: 'Lato', fontWeight: AppTypography.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancel the ${entry.slotName} slot (${entry.timeRange})?',
              style: const TextStyle(fontFamily: 'Lato'),
            ),
            const SizedBox(height: AppSizes.spacing12),
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 2,
              style: const TextStyle(
                  fontFamily: 'Lato', fontSize: AppTypography.fontSize14),
              decoration: InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Keep slot', style: TextStyle(fontFamily: 'Lato')),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(ctx).pop(text.isEmpty ? 'Cancelled by user' : text);
            },
            child: const Text('Cancel slot',
                style:
                    TextStyle(fontFamily: 'Lato', color: AppColors.errorColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(confirmedSlotsProvider).valueOrNull?[widget.date];
    final slots = day?.slots ?? const <ConfirmedSlotEntry>[];
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
                  const Icon(Icons.verified_rounded,
                      color: AppColors.darkGreen, size: AppSizes.icon20),
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confirmed slots',
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
            if (slots.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSizes.spacing24),
                child: Text('No confirmed slots for this date.',
                    style: TextStyle(fontFamily: 'Lato')),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  itemCount: slots.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.spacing12),
                  itemBuilder: (_, i) => _ConfirmedSlotCard(
                    entry: slots[i],
                    cancelling: _cancellingOrderId == slots[i].orderId,
                    busy: _cancellingOrderId != null,
                    onCancel: () => _cancel(slots[i]),
                  ),
                ),
              ),
            const SizedBox(height: AppSizes.spacing8),
          ],
        ),
      ),
    );
  }
}

/// A single confirmed slot row with its categories and a cancel action.
class _ConfirmedSlotCard extends StatelessWidget {
  const _ConfirmedSlotCard({
    required this.entry,
    required this.cancelling,
    required this.busy,
    required this.onCancel,
  });

  final ConfirmedSlotEntry entry;
  final bool cancelling;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cancelled = entry.isCancelled;
    final visual = entry.categories.isNotEmpty
        ? _categoryVisual(entry.categories.first.dishCategory)
        : (icon: Icons.local_shipping_rounded, color: AppColors.primaryGreen);
    final iconColor = cancelled ? AppColors.textTertiary : visual.color;

    return Opacity(
      opacity: cancelled ? 0.65 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        decoration: BoxDecoration(
          color: cancelled
              ? AppColors.borderColor.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border:
              Border.all(color: AppColors.borderColor.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: Icon(visual.icon,
                      size: AppSizes.icon16, color: iconColor),
                ),
                const SizedBox(width: AppSizes.spacing8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.slotName,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                          decoration:
                              cancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.timeRange,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
                if (cancelled)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                    ),
                    child: const Text(
                      'Order Cancelled by you ',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize10,
                        fontWeight: AppTypography.bold,
                        color: AppColors.errorColor,
                        fontFamily: 'Lato',
                      ),
                    ),
                  )
                else if (cancelling)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.errorColor),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: busy ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.errorColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon:
                        const Icon(Icons.close_rounded, size: AppSizes.icon16),
                    label: const Text('Cancel order ',
                        style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: AppTypography.fontSize12,
                            fontWeight: AppTypography.semiBold)),
                  ),
              ],
            ),
            if (entry.categories.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in entry.categories)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _categoryVisual(c.dishCategory)
                            .color
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                      ),
                      child: Text(
                        c.dishCategory,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize10,
                          fontWeight: AppTypography.semiBold,
                          color: _categoryVisual(c.dishCategory).color,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                ],
              ),
            ],
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
                child:
                    const Text('Retry', style: TextStyle(fontFamily: 'Lato')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
