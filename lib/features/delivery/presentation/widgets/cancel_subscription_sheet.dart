import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../models/subscription_cancel_preview_model.dart';
import '../../providers/subscription_cancel_provider.dart';
import '../../providers/wallet_provider.dart';

/// Bottom sheet that previews the refund for cancelling an active subscription
/// and lets the user confirm. Self-contained — open it from anywhere:
///
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => CancelSubscriptionSheet(subscriptionId: id),
/// );
/// ```
class CancelSubscriptionSheet extends ConsumerStatefulWidget {
  const CancelSubscriptionSheet({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  ConsumerState<CancelSubscriptionSheet> createState() =>
      _CancelSubscriptionSheetState();
}

class _CancelSubscriptionSheetState
    extends ConsumerState<CancelSubscriptionSheet> {
  String? _selectedMethod;
  bool _isCancelling = false;

  Future<void> _confirmCancellation(String refundMethod) async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);

    // Captured before the async gap so they stay valid after the sheet pops.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final res = await repo.cancelSubscription(
        subscriptionId: widget.subscriptionId,
        refundMethod: refundMethod,
      );

      if (res.success) {
        // Refresh wallet + subscription so the rest of the app reflects it.
        await ref.read(walletProvider.notifier).loadWalletBalance();
        if (!mounted) return;
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty
                ? res.message
                : 'Subscription cancelled. Your refund is on its way.'),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        setState(() => _isCancelling = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty
                ? res.message
                : 'Could not cancel the subscription. Please try again.'),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not cancel the subscription. Please try again.'),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewAsync =
        ref.watch(subscriptionCancelPreviewProvider(widget.subscriptionId));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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
                  const Icon(Icons.cancel_outlined,
                      color: AppColors.errorColor, size: AppSizes.icon20),
                  const SizedBox(width: AppSizes.spacing8),
                  const Expanded(
                    child: Text(
                      'Cancel Subscription',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize18,
                        fontWeight: AppTypography.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
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
              child: previewAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryGreen),
                  ),
                ),
                error: (e, _) => _CancelError(
                  onRetry: () => ref.invalidate(
                    subscriptionCancelPreviewProvider(widget.subscriptionId),
                  ),
                ),
                data: (preview) => _buildPreviewBody(preview),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBody(SubscriptionCancelPreview p) {
    final methods = p.availableRefundMethods;
    // Resolve the effective selected method (default to the first available).
    final selected = (_selectedMethod != null && methods.contains(_selectedMethod))
        ? _selectedMethod!
        : (methods.isNotEmpty ? methods.first : '');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Meals progress
          if (p.totalMeals > 0)
            Text(
              '${p.mealsConsumed} of ${p.totalMeals} meals consumed'
              '${p.mealsPerDay > 0 ? ' · ${p.mealsPerDay}/day' : ''}',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontFamily: 'Lato',
              ),
            ),
          const SizedBox(height: AppSizes.spacing12),

          // Refund breakdown
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSizes.radius12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                _BreakdownRow(
                  label: 'Plan amount',
                  value: _fmtMoney(p.planAmount),
                ),
                if (p.consultationFee > 0) ...[
                  const SizedBox(height: AppSizes.spacing12),
                  _BreakdownRow(
                    label: 'Less: consultation fee',
                    value: '− ${_fmtMoney(p.consultationFee)}',
                  ),
                ],
                if (p.mealsConsumed > 0) ...[
                  const SizedBox(height: AppSizes.spacing12),
                  _BreakdownRow(
                    label:
                        'Less: meals consumed (${p.mealsConsumed} × ${_fmtMoney(p.pricePerMeal)})',
                    value: '− ${_fmtMoney(p.consumedMealsValue)}',
                  ),
                ],
                const SizedBox(height: AppSizes.spacing12),
                const Divider(height: 1, color: AppColors.borderColor),
                const SizedBox(height: AppSizes.spacing12),
                _BreakdownRow(
                  label: 'Refund amount',
                  value: _fmtMoney(p.refundAmount),
                  isBold: true,
                ),
              ],
            ),
          ),

          // Refund method
          if (methods.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacing16),
            const Text(
              'Refund to',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.semiBold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            for (final m in methods)
              _RefundMethodTile(
                label: _refundMethodLabel(m),
                selected: m == selected,
                onTap: _isCancelling
                    ? null
                    : () => setState(() => _selectedMethod = m),
              ),
          ],

          const SizedBox(height: AppSizes.spacing16),

          // Actions
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton(
              onPressed: (_isCancelling || selected.isEmpty)
                  ? null
                  : () => _confirmCancellation(selected),
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
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Confirm Cancellation · Refund ${_fmtMoney(p.refundAmount)}',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize14,
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
                'Keep my subscription',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.primaryGreen,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtMoney(double v) =>
    '₹${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';

String _refundMethodLabel(String method) {
  switch (method.toLowerCase()) {
    case 'wallet':
      return 'FitKhao Wallet';
    case 'razorpay':
      return 'Original payment method';
    default:
      return method.isEmpty
          ? method
          : '${method[0].toUpperCase()}${method.substring(1)}';
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final weight = isBold ? AppTypography.bold : AppTypography.regular;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              fontWeight: weight,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spacing12),
        Text(
          value,
          style: TextStyle(
            fontSize:
                isBold ? AppTypography.fontSize16 : AppTypography.fontSize14,
            fontWeight: weight,
            color: isBold ? AppColors.primaryGreen : AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }
}

class _RefundMethodTile extends StatelessWidget {
  const _RefundMethodTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing12,
          vertical: AppSizes.spacing12,
        ),
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
            const SizedBox(width: AppSizes.spacing10),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight:
                    selected ? AppTypography.semiBold : AppTypography.regular,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelError extends StatelessWidget {
  const _CancelError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.spacing24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 40, color: AppColors.errorColor),
          const SizedBox(height: AppSizes.spacing12),
          const Text(
            'Could not load cancellation details.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen),
            ),
            child: const Text('Retry', style: TextStyle(fontFamily: 'Lato')),
          ),
        ],
      ),
    );
  }
}
