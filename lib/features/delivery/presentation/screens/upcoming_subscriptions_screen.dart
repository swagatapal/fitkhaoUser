import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/utils/time_converter.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/upcoming_subscription_model.dart';
import '../../providers/subscription_detail_provider.dart';
import '../../providers/wallet_provider.dart';

/// Lists the user's upcoming (paid, not yet started) subscriptions from
/// GET /api/subscription/upcoming, each with a cancel action.
class UpcomingSubscriptionsScreen extends ConsumerWidget {
  const UpcomingSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingSubscriptionsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          automaticallyImplyLeading: false,
          toolbarHeight: 64,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
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
                const Expanded(
                  child: Text(
                    'Upcoming Plans',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize20,
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () => ref.refresh(upcomingSubscriptionsProvider.future),
          child: upcoming.when(
            loading: () => const _Skeleton(),
            error: (e, _) => _Message(
              icon: Icons.error_outline_rounded,
              iconColor: AppColors.errorColor,
              title: 'Could not load upcoming plans',
              subtitle: e.toString().replaceFirst('Exception: ', ''),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(upcomingSubscriptionsProvider),
            ),
            data: (subs) {
              if (subs.isEmpty) {
                return const _Message(
                  icon: Icons.event_available_rounded,
                  iconColor: AppColors.primaryGreen,
                  title: 'No upcoming plans',
                  subtitle:
                      'Plans you renew in advance will show up here until they start.',
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSizes.screenPaddingHorizontal),
                itemCount: subs.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSizes.spacing16),
                itemBuilder: (_, i) => _UpcomingCard(sub: subs[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Card ────────────────────────────────────────────────────────────────────

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.sub});

  final UpcomingSubscription sub;

  String get _startsIn {
    if (sub.remainingDays <= 0) return 'Starts soon';
    if (sub.remainingDays == 1) return 'Starts in 1 day';
    return 'Starts in ${sub.remainingDays} days';
  }

  @override
  Widget build(BuildContext context) {
    final start = convertMongoUtcToIstExceptTime(
        sub.serviceStartDate.isNotEmpty ? sub.serviceStartDate : sub.startDate);
    final end = convertMongoUtcToIstExceptTime(sub.endDate);

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: name + code, "starts in" pill ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.planName,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing4),
                    Text(
                      [
                        sub.planCode,
                        if (sub.mealsPerDay > 0) '${sub.mealsPerDay} meals/day',
                        if (sub.isRenewal) 'Renewal',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing8,
                  vertical: AppSizes.spacing4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radius20),
                ),
                child: Text(
                  _startsIn,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize10,
                    fontWeight: AppTypography.bold,
                    color: AppColors.primaryGreen,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.spacing12),

          // ── Dates ──
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            child: Row(
              children: [
                Expanded(child: _DateCell(label: 'Starts', value: start)),
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.borderColor,
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(child: _DateCell(label: 'Ends', value: end)),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.spacing12),

          // ── What was paid ──
          _Line(label: 'Plan amount', value: _money(sub.planAmount)),
          if (sub.cancelAnytimeSelected && sub.cancelAnytimeFee > 0)
            _Line(
                label: 'Cancel-anytime fee',
                value: _money(sub.cancelAnytimeFee)),
          if (sub.gstAmount > 0)
            _Line(
              label: 'GST (${sub.gstPercent.toStringAsFixed(0)}%)',
              value: _money(sub.gstAmount),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.spacing6),
            child: Divider(height: 1, color: AppColors.borderColor),
          ),
          _Line(
            label: 'Total paid',
            value: _money(sub.totalAmount),
            bold: true,
          ),
          if (sub.paymentMethod.isNotEmpty)
            _Line(
              label: 'Paid via',
              value: sub.paymentMethodLabel,
              muted: true,
            ),

          const SizedBox(height: AppSizes.spacing12),

          // ── Cancel ──
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeightSmall,
            child: OutlinedButton.icon(
              onPressed: sub.id.isEmpty
                  ? null
                  : () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _CancelUpcomingSheet(sub: sub),
                      ),
              icon: const Icon(Icons.cancel_outlined, size: AppSizes.icon18),
              label: const Text(
                'Cancel this plan',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.bold,
                  fontFamily: 'Lato',
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.errorColor,
                side: BorderSide(
                    color: AppColors.errorColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTypography.fontSize10,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: AppTypography.semiBold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.bold = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: muted ? AppTypography.fontSize12 : AppTypography.fontSize14,
      fontWeight: bold ? AppTypography.bold : AppTypography.regular,
      color: muted ? AppColors.textSecondary : AppColors.textPrimary,
      fontFamily: 'Lato',
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            value,
            style: bold ? style.copyWith(color: AppColors.primaryGreen) : style,
          ),
        ],
      ),
    );
  }
}

// ─── Cancel sheet (optional reason) ──────────────────────────────────────────

class _CancelUpcomingSheet extends ConsumerStatefulWidget {
  const _CancelUpcomingSheet({required this.sub});

  final UpcomingSubscription sub;

  @override
  ConsumerState<_CancelUpcomingSheet> createState() =>
      _CancelUpcomingSheetState();
}

class _CancelUpcomingSheetState extends ConsumerState<_CancelUpcomingSheet> {
  final _reasonController = TextEditingController();
  bool _isCancelling = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    setState(() => _isCancelling = true);

    // Captured before the async gap so they stay valid after the sheet pops.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final res = await ref
          .read(subscriptionRepositoryProvider)
          .cancelUpcomingSubscription(
            subscriptionId: widget.sub.id,
            reason: _reasonController.text,
          );

      if (!res.success) {
        throw Exception(res.message.isNotEmpty
            ? res.message
            : 'Could not cancel this plan. Please try again.');
      }

      // Refresh the list, and the wallet + profile so balances and the
      // renewal state elsewhere in the app reflect the cancellation.
      ref.invalidate(upcomingSubscriptionsProvider);
      ref.read(walletProvider.notifier).loadWalletBalance();
      ref.read(authProvider.notifier).loadProfile();

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text([
            res.message.isNotEmpty
                ? res.message
                : 'Upcoming plan cancelled.',
            if (res.note.isNotEmpty) res.note,
          ].join('\n')),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      final message = e is AppException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.sub;
    final start = convertMongoUtcToIstExceptTime(
        sub.serviceStartDate.isNotEmpty ? sub.serviceStartDate : sub.startDate);

    return Padding(
      // Lifts the sheet above the keyboard while the reason is typed.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacing20,
              AppSizes.spacing12,
              AppSizes.spacing20,
              AppSizes.spacing20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),
                const Text(
                  'Cancel upcoming plan?',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize18,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                Text(
                  '${sub.planName}${start.isNotEmpty ? ', starting $start,' : ''} '
                  'will be cancelled. You paid ${_money(sub.totalAmount)}; '
                  'the refund is processed separately.',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing16),
                TextField(
                  controller: _reasonController,
                  enabled: !_isCancelling,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 250,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'Tell us why you are cancelling',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                      borderSide: const BorderSide(
                          color: AppColors.primaryGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isCancelling ? null : _cancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.errorColor.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                      ),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'Confirm Cancellation',
                            style: TextStyle(
                              fontSize: AppTypography.fontSize16,
                              fontWeight: AppTypography.bold,
                              fontFamily: 'Lato',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed:
                        _isCancelling ? null : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Keep this plan',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
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

// ─── States ──────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPaddingHorizontal),
      children: List.generate(
        2,
        (_) => Container(
          height: 260,
          margin: const EdgeInsets.only(bottom: AppSizes.spacing16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
        ),
      ),
    );
  }
}

/// Empty / error message, scrollable so pull-to-refresh still works.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.spacing24),
      children: [
        const SizedBox(height: AppSizes.spacing60),
        Icon(icon, size: 56, color: iconColor.withValues(alpha: 0.6)),
        const SizedBox(height: AppSizes.spacing16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: AppTypography.semiBold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppTypography.fontSize13,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSizes.spacing20),
          Center(
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(actionLabel!,
                  style: const TextStyle(fontFamily: 'Lato')),
            ),
          ),
        ],
      ],
    );
  }
}

String _money(double v) =>
    '₹${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';
