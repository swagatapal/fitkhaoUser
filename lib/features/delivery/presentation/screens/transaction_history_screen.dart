import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_history_provider.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionHistoryProvider.notifier).load(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(transactionHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TransactionHistoryState state) {
    if (state.isLoading && state.isEmpty) {
      return _buildLoadingState();
    }
    if (state.error != null && state.isEmpty) {
      return _buildErrorState(state.error!);
    }
    if (state.isEmpty) {
      return _buildEmptyState();
    }
    return _buildTransactionList(state);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p20,
        vertical: AppSizes.spacing8,
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
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.textWhite,
                size: AppSizes.icon24,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Transaction History",
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  "View all your wallet transactions",
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          Image.asset("assets/images/logo.png", height: 50, width: 50),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.screenPaddingHorizontal),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
      itemBuilder: (_, __) => Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.errorColor),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              message,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: AppTypography.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spacing16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(transactionHistoryProvider.notifier).refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Icon(Icons.receipt_long, size: 48, color: AppColors.textTertiary),
        const SizedBox(height: AppSizes.spacing12),
        const Text(
          'No transactions yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textSecondary,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(TransactionHistoryState state) {
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () => ref.read(transactionHistoryProvider.notifier).refresh(),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSizes.screenPaddingHorizontal),
        // +1 row for the pagination footer.
        itemCount: state.transactions.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
        itemBuilder: (context, index) {
          if (index == state.transactions.length) {
            return _PaginationFooter(
              isLoadingMore: state.isLoadingMore,
              hasMore: state.hasMore,
            );
          }
          return _TransactionCard(transaction: state.transactions[index]);
        },
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  final bool isLoadingMore;
  final bool hasMore;

  const _PaginationFooter({required this.isLoadingMore, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.spacing16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryGreen),
          ),
        ),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.spacing16),
        child: Center(
          child: Text(
            'No more transactions',
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              color: AppColors.textTertiary,
              fontFamily: 'Lato',
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSizes.spacing16);
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const _TransactionCard({required this.transaction});

  bool get _isSubscription =>
      (transaction.metadata?.subscriptionId ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final subscriptionId = transaction.metadata?.subscriptionId;
    final planCode = transaction.metadata?.planCode;

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing8),
                decoration: BoxDecoration(
                  color: transaction.isDebit
                      ? AppColors.errorColor.withValues(alpha: 0.1)
                      : AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                child: Icon(
                  transaction.isDebit
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: transaction.isDebit
                      ? AppColors.errorColor
                      : AppColors.successColor,
                  size: AppSizes.icon20,
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _getCategoryTitle(transaction.category),
                            style: const TextStyle(
                              fontSize: AppTypography.fontSize16,
                              fontWeight: AppTypography.semiBold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ),
                        if (planCode != null && planCode.isNotEmpty) ...[
                          const SizedBox(width: AppSizes.spacing6),
                          _PlanCodeChip(code: planCode),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.formattedDateShort,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.isDebit ? '-' : '+'}${transaction.formattedAmount}',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize16,
                      fontWeight: AppTypography.bold,
                      color: transaction.isDebit
                          ? AppColors.errorColor
                          : AppColors.successColor,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing8,
                      vertical: AppSizes.spacing2,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(transaction.status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                    ),
                    child: Text(
                      _getStatusText(transaction.status),
                      style: TextStyle(
                        fontSize: AppTypography.fontSize10,
                        fontWeight: AppTypography.semiBold,
                        color: _getStatusColor(transaction.status),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (transaction.description.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacing8),
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSizes.radius4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Text(
                      transaction.description,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSizes.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Balance After',
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: AppColors.textTertiary,
                  fontFamily: 'Lato',
                ),
              ),
              Text(
                transaction.formattedBalanceAfter,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
          // Pricing breakdown — shown only when the transaction carries one.
          if (transaction.metadata?.pricing != null)
            _PriceBreakdown(pricing: transaction.metadata!.pricing!),
          // Subscription transactions can fetch their invoice.
          if (_isSubscription && subscriptionId != null) ...[
            const SizedBox(height: AppSizes.spacing12),
            _InvoiceButton(subscriptionId: subscriptionId),
          ],
        ],
      ),
    );
  }

  String _getCategoryTitle(String category) {
    switch (category.toLowerCase()) {
      case 'order_payment':
        return 'Order Payment';
      case 'order_refund':
        return 'Order Refund';
      case 'wallet_topup':
      case 'topup':
        return 'Wallet Top-up';
      case 'refund':
        return 'Refund';
      case 'subscription':
      case 'subscription_purchase':
        return 'Subscription Purchase';
      case 'subscription_refund':
      case 'subscription_cancellation':
        return 'Subscription Refund';
      default:
        return category
            .split('_')
            .where((w) => w.isNotEmpty)
            .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.successColor;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return AppColors.errorColor;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _PlanCodeChip extends StatelessWidget {
  final String code;
  const _PlanCodeChip({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: AppTypography.fontSize10,
          fontWeight: AppTypography.bold,
          color: AppColors.primaryGreen,
          letterSpacing: 0.4,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}

/// Itemised pricing breakdown for a (subscription) transaction.
class _PriceBreakdown extends StatelessWidget {
  final TransactionPricing pricing;
  const _PriceBreakdown({required this.pricing});

  String _money(double v) {
    final whole = v == v.roundToDouble();
    return '₹${v.toStringAsFixed(whole ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final gstPct = (pricing.gstRate * 100);
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.spacing8),
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          _row('Plan amount', _money(pricing.planAmount)),
          if (pricing.cancelAnytimeSelected || pricing.cancelAnytimeFee > 0) ...[
            const SizedBox(height: AppSizes.spacing6),
            _row('Cancel-anytime fee', _money(pricing.cancelAnytimeFee)),
          ],
          const SizedBox(height: AppSizes.spacing6),
          _row('Subtotal', _money(pricing.subtotal)),
          if (pricing.gstAmount > 0) ...[
            const SizedBox(height: AppSizes.spacing6),
            _row('GST (${gstPct.toStringAsFixed(gstPct == gstPct.roundToDouble() ? 0 : 1)}%)',
                _money(pricing.gstAmount)),
          ],
          const Divider(height: AppSizes.spacing16),
          _row('Total paid', _money(pricing.totalAmount), bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            fontWeight: bold ? AppTypography.bold : AppTypography.regular,
            color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            fontWeight: bold ? AppTypography.bold : AppTypography.medium,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }
}

/// Per-subscription invoice button — watches only its own loading slice, so a
/// tap rebuilds just this button, not the whole list.
class _InvoiceButton extends ConsumerWidget {
  final String subscriptionId;
  const _InvoiceButton({required this.subscriptionId});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref
          .read(transactionHistoryProvider.notifier)
          .fetchInvoiceUrl(subscriptionId);

      if (url == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Invoice is not available yet.'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Could not open the invoice.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorColor,
        ));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not load the invoice. Please try again.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      transactionHistoryProvider
          .select((s) => s.isInvoiceLoading(subscriptionId)),
    );

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : () => _open(context, ref),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(color: AppColors.primaryGreen),
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryGreen),
              )
            : const Icon(Icons.receipt_long_rounded, size: AppSizes.icon18),
        label: Text(
          isLoading ? 'Loading invoice…' : 'View Invoice',
          style: const TextStyle(
            fontSize: AppTypography.fontSize13,
            fontWeight: AppTypography.semiBold,
            fontFamily: 'Lato',
          ),
        ),
      ),
    );
  }
}
