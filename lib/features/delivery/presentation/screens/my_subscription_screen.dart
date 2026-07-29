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
import '../../../consultation/providers/consultation_providers.dart';
import '../widgets/delivery_plan_manager_tab.dart';
import '../../../dashboard/models/meal_plan_model.dart';
import '../../../dashboard/providers/meal_plan_provider.dart';
import '../../../policy/models/app_constants_model.dart';
import '../../../policy/providers/app_constants_provider.dart';
import '../../../profile/providers/delivery_address_provider.dart';
import '../../models/subscription_timeline_model.dart';
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
      child: DefaultTabController(
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
                      const DeliveryPlanManagerTab(),
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
          Tab(text: 'Delivery Plan Manager'),
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

class _TimelineContent extends ConsumerWidget {
  const _TimelineContent({required this.timeline});

  final SubscriptionTimeline timeline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = timeline.steps;
    final days = timeline.dailyMeals;

    // Meeting link for the first consultation — same source the booking screen
    // uses (token-scoped active consultation). Shown right after that step.
    final booking = ref.watch(activeBookingProvider).valueOrNull;
    final firstConsultationIdx =
        steps.indexWhere((s) => s.key.toLowerCase().startsWith('consultation'));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing16,
        AppSizes.screenPaddingHorizontal,
        AppSizes.spacing32,
      ),
      children: [
        // const _CancellationPolicyBanner(),
        if (timeline.subscription != null)
          _TimelineSummaryCard(subscription: timeline.subscription!),
        const SizedBox(height: AppSizes.spacing16),

        const _HealthProfileButton(),
        const SizedBox(height: AppSizes.spacing12),
        _ConsultationSlotButton(enabled: _canBookConsultation(steps)),

        if (steps.isNotEmpty) ...[
          const SizedBox(height: AppSizes.spacing20),
          const _SectionHeader('Your journey'),
          const SizedBox(height: AppSizes.spacing12),
          for (var i = 0; i < steps.length; i++) ...[
            _TimelineStepTile(
              step: steps[i],
              isFirst: i == 0,
              isLast: i == steps.length - 1,
            ),
            // After the first consultation step, surface the meeting link when
            // the nutritionist has provided one.
            if (i == firstConsultationIdx &&
                booking != null &&
                booking.hasMeetingLink)
              _JourneyMeetingLinkCard(link: booking.meetingLink),
          ],
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
/// Disabled once a consultation is completed, until the meal plan is provided.
class _ConsultationSlotButton extends StatelessWidget {
  const _ConsultationSlotButton({this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? _kAccent : AppColors.textTertiary;
    return Opacity(
      opacity: enabled ? 1 : 0.75,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          onTap: enabled
              ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BookConsultationScreen(),
                    ),
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : const Color(0xFFF4F5F6),
              borderRadius: BorderRadius.circular(AppSizes.radius12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: Icon(Icons.event_available_rounded,
                      color: accent, size: AppSizes.icon20),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose consultation time slot',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enabled
                            ? 'Book a session with a nutritionist'
                            : 'Available after your meal plan is provided',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(enabled ? Icons.chevron_right_rounded : Icons.lock_rounded,
                    color: accent, size: AppSizes.icon24),
              ],
            ),
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
        borderRadius: BorderRadius.circular(AppSizes.radius8),
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
    // Only completed steps surface their date — pending/upcoming steps carry no
    // meaningful completion date, so it stays hidden until they finish.
    final dateStr = step.status == TimelineStatus.completed && step.date != null
        ? convertMongoUtcToIst(step.date!)
        : '';

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

/// Tappable Google-Meet card shown under the first consultation step when the
/// nutritionist has attached a meeting link. Indented to align with the step
/// card (past the 36px rail + 12px gap).
class _JourneyMeetingLinkCard extends StatelessWidget {
  const _JourneyMeetingLinkCard({required this.link});

  final String link;

  static const Color _meetBlue = Color(0xFF1A73E8);

  Future<void> _join(BuildContext context) async {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open the meeting link.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 36 + AppSizes.spacing12,
        bottom: AppSizes.spacing12,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          onTap: () => _join(context),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            decoration: BoxDecoration(
              color: _meetBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppSizes.radius12),
              border: Border.all(color: _meetBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing8),
                  decoration: BoxDecoration(
                    color: _meetBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: const Icon(Icons.videocam_rounded,
                      color: _meetBlue, size: AppSizes.icon24),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Join Google Meet',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.bold,
                          color: _meetBlue,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        link,
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
                const Icon(Icons.open_in_new_rounded,
                    color: _meetBlue, size: AppSizes.icon20),
              ],
            ),
          ),
        ),
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
            _MealRow(meal: day.meals[i], deliveryDate: day.parsedDate),
          ],
        ],
      ),
    );
  }
}

class _MealRow extends ConsumerStatefulWidget {
  const _MealRow({required this.meal, this.deliveryDate});

  final TimelineMeal meal;

  /// The day this meal is delivered — used for the change/cancel cutoff check.
  final DateTime? deliveryDate;

  @override
  ConsumerState<_MealRow> createState() => _MealRowState();
}

class _MealRowState extends ConsumerState<_MealRow> {
  bool _busy = false;

  TimelineMeal get meal => widget.meal;

  Future<void> _cancelOrder() async {
    final reason = await _askReason();
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref
          .read(orderRepositoryProvider)
          .cancelOrder(orderId: meal.orderId, reason: reason);
      if (!mounted) return;
      setState(() => _busy = false);
      final ok = res['success'] == true;
      if (ok) ref.invalidate(subscriptionTimelineProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? 'Order cancelled.'
            : (res['message'] as String?) ?? 'Could not cancel this order.'),
        backgroundColor: ok ? AppColors.primaryGreen : AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not cancel this order. Please try again.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController(text: "Don't need this delivery");
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?',
            style:
                TextStyle(fontFamily: 'Lato', fontWeight: AppTypography.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${meal.slot}${meal.slotTime.isEmpty ? '' : ' (${meal.slotTime})'}'
              '${meal.orderNumber.isEmpty ? '' : ' · ${meal.orderNumber}'}',
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
                labelText: 'Reason (optional)',
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
                const Text('Keep order', style: TextStyle(fontFamily: 'Lato')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Cancel order',
                style:
                    TextStyle(fontFamily: 'Lato', color: AppColors.errorColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _changeSlot() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealOrderChangeSheet(meal: meal),
    );
    if (changed == true && mounted) {
      ref.invalidate(subscriptionTimelineProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Delivery updated.'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cutoffHour = ref
            .watch(appConstantsProvider)
            .valueOrNull
            ?.subscriptionSlotChangeCutoffHour ??
        AppConstants.defaults.subscriptionSlotChangeCutoffHour;
    final withinCutoff = _withinChangeCutoff(widget.deliveryDate, cutoffHour);
    final canModify = meal.isActionable && withinCutoff;
    // Order is still open but the change/cancel window on the delivery day has
    // closed → show a lock hint instead of the actions menu.
    final locked = meal.isActionable && !withinCutoff;

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
        _MealStatusChip(label: meal.statusLabel, status: meal.status),
        if (locked) ...[
          const SizedBox(width: 4),
          Tooltip(
            message:
                'Changes closed after ${_formatHour(cutoffHour)} IST on the delivery day',
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(Icons.lock_clock_rounded,
                size: AppSizes.icon18,
                color: AppColors.textSecondary.withValues(alpha: 0.7)),
          ),
        ],
        if (canModify) ...[
          const SizedBox(width: 2),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryGreen),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: AppSizes.icon20, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              onSelected: (v) {
                if (v == 'change') _changeSlot();
                if (v == 'cancel') _cancelOrder();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'change',
                  child: Row(
                    children: [
                      Icon(Icons.edit_calendar_rounded,
                          size: AppSizes.icon18, color: AppColors.primaryGreen),
                      SizedBox(width: AppSizes.spacing8),
                      Text('Change slot / address',
                          style: TextStyle(fontFamily: 'Lato')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.close_rounded,
                          size: AppSizes.icon18, color: AppColors.errorColor),
                      SizedBox(width: AppSizes.spacing8),
                      Text('Cancel order',
                          style: TextStyle(
                              fontFamily: 'Lato', color: AppColors.errorColor)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

/// Status chip that falls back to the raw label (e.g. "Confirmed").
class _MealStatusChip extends StatelessWidget {
  const _MealStatusChip({required this.label, required this.status});

  final String label;
  final TimelineStatus status;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final c = status == TimelineStatus.unknown
        ? AppColors.primaryGreen
        : _timelineStatusVisual(status).color;
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

/// Bottom sheet to change a daily order's delivery slot and/or address
/// (PUT /api/orders/{orderId}/subscription-slot). The server enforces the
/// 6 AM IST deadline; its message is surfaced. Pops `true` on success.
class _MealOrderChangeSheet extends ConsumerStatefulWidget {
  const _MealOrderChangeSheet({required this.meal});

  final TimelineMeal meal;

  @override
  ConsumerState<_MealOrderChangeSheet> createState() =>
      _MealOrderChangeSheetState();
}

class _MealOrderChangeSheetState extends ConsumerState<_MealOrderChangeSheet> {
  String? _slotId; // null = keep current
  String? _addressId; // null = keep current
  bool _submitting = false;

  bool get _hasChange => _slotId != null || _addressId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(addressProvider).addresses.isEmpty) {
        ref.read(addressProvider.notifier).loadAddresses(silent: true);
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting || !_hasChange) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res =
          await ref.read(orderRepositoryProvider).updateSubscriptionOrderSlot(
                orderId: widget.meal.orderId,
                slotId: _slotId,
                deliveryAddressId: _addressId,
              );
      if (!mounted) return;
      if (res['success'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
        content: Text((res['message'] as String?)?.isNotEmpty == true
            ? res['message'] as String
            : 'Could not update this delivery.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(deliverySlotListProvider);
    final addresses = ref.watch(addressProvider.select((s) => s.addresses));

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Change delivery',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize18,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                        Text(
                          '${widget.meal.slot}'
                          '${widget.meal.orderNumber.isEmpty ? '' : ' · ${widget.meal.orderNumber}'}',
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
                  _deadlineNote(),
                  const SizedBox(height: AppSizes.spacing16),
                  const _ChangeLabel('Delivery slot'),
                  const SizedBox(height: AppSizes.spacing8),
                  slotsAsync.when(
                    loading: () => const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSizes.spacing16),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryGreen)),
                    ),
                    error: (_, __) => _ChangeRetry(
                      message: 'Could not load slots.',
                      onRetry: () => ref.invalidate(deliverySlotListProvider),
                    ),
                    data: (slots) => Column(
                      children: [
                        for (final s in slots)
                          _ChangeOption(
                            title: s.slotName,
                            subtitle: s.timeRange,
                            selected: _slotId == s.id,
                            onTap: _submitting
                                ? null
                                : () => setState(() =>
                                    _slotId = _slotId == s.id ? null : s.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing16),
                  const _ChangeLabel('Delivery address'),
                  const SizedBox(height: 2),
                  Text(
                    'Leave unselected to keep the current one.',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize10,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  if (addresses.isEmpty)
                    Text(
                      'No saved addresses found.',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                        fontFamily: 'Lato',
                      ),
                    )
                  else
                    for (final a in addresses)
                      _ChangeOption(
                        title: a.label.isEmpty
                            ? 'Address'
                            : '${a.label[0].toUpperCase()}${a.label.substring(1)}',
                        subtitle: a.formattedAddress,
                        selected: _addressId == a.id,
                        onTap: _submitting
                            ? null
                            : () => setState(() =>
                                _addressId = _addressId == a.id ? null : a.id),
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
                  onPressed: _hasChange && !_submitting ? _submit : null,
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
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _hasChange
                              ? 'Update delivery'
                              : 'Pick a new slot or address',
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

  Widget _deadlineNote() {
    final cutoffHour = ref
            .watch(appConstantsProvider)
            .valueOrNull
            ?.subscriptionSlotChangeCutoffHour ??
        AppConstants.defaults.subscriptionSlotChangeCutoffHour;
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded,
              size: AppSizes.icon18, color: _kAccent),
          const SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Text(
              'Changes are allowed only before ${_formatHour(cutoffHour)} IST on the delivery day.',
              style: const TextStyle(
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

class _ChangeLabel extends StatelessWidget {
  const _ChangeLabel(this.text);
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

class _ChangeRetry extends StatelessWidget {
  const _ChangeRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            size: AppSizes.icon18, color: AppColors.errorColor),
        const SizedBox(width: AppSizes.spacing8),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato')),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry',
              style:
                  TextStyle(fontFamily: 'Lato', color: AppColors.primaryGreen)),
        ),
      ],
    );
  }
}

class _ChangeOption extends StatelessWidget {
  const _ChangeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

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
                  Text(title,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      )),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                          fontFamily: 'Lato',
                        )),
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

/// Whether the "Choose consultation time slot" button is enabled.
///
/// Once a consultation is `completed`, booking the next one is locked until the
/// matching meal plan is provided (e.g. `consultation_1` completed →
/// disabled until `meal_plan_1` is `completed`).
bool _canBookConsultation(List<TimelineStep> steps) {
  int? lastCompletedConsult;
  for (final s in steps) {
    if (s.status == TimelineStatus.completed &&
        s.key.startsWith('consultation_')) {
      final n = int.tryParse(s.key.substring('consultation_'.length));
      if (n != null &&
          (lastCompletedConsult == null || n > lastCompletedConsult)) {
        lastCompletedConsult = n;
      }
    }
  }
  if (lastCompletedConsult == null) return true;

  final mealKey = 'meal_plan_$lastCompletedConsult';
  for (final s in steps) {
    if (s.key == mealKey) return s.status == TimelineStatus.completed;
  }
  return true; // no gating meal-plan step for this consultation
}

/// A subscription-slot order can be changed/cancelled only before
/// [cutoffHour]:00 IST on its delivery day.
bool _withinChangeCutoff(DateTime? deliveryDate, int cutoffHour) {
  if (deliveryDate == null) return true; // no date → don't block client-side
  final cutoffUtc = DateTime.utc(
    deliveryDate.year,
    deliveryDate.month,
    deliveryDate.day,
    cutoffHour,
  ).subtract(const Duration(hours: 5, minutes: 30)); // IST → UTC
  return DateTime.now().toUtc().isBefore(cutoffUtc);
}

/// "6:00 AM" from a 24h hour value.
String _formatHour(int h) {
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:00 $period';
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
