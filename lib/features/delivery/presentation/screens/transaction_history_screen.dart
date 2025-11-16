import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../models/transaction_model.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactionHistory();
  }

  Future<void> _loadTransactionHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final walletRepo = ref.read(walletRepositoryProvider);
      final response = await walletRepo.getTransactionHistory();

      if (mounted) {
        setState(() {
          _transactions = response.data.transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[TransactionHistoryScreen] Error loading transactions: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load transaction history. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _transactions.isEmpty
                          ? _buildEmptyState()
                          : _buildTransactionList(),
            ),
          ],
        ),
      ),
    );
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
          CircleAvatar(
            radius: AppSizes.spacing24,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
            backgroundImage: const NetworkImage(
              "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTFcyssMbcvEkMiCDu8zrO9VuN-Yy1aW1vycA&s",
            ),
            onBackgroundImageError: (exception, stackTrace) {},
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                  width: AppSizes.borderThin,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryGreen,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.errorColor,
            ),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: AppTypography.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spacing16),
            ElevatedButton(
              onPressed: _loadTransactionHistory,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.receipt_long,
            size: 48,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: AppSizes.spacing12),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return RefreshIndicator(
      onRefresh: _loadTransactionHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.screenPaddingHorizontal),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return _TransactionCard(transaction: transaction);
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      _getCategoryTitle(transaction.category),
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
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
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
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
              Text(
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
        ],
      ),
    );
  }

  String _getCategoryTitle(String category) {
    switch (category.toLowerCase()) {
      case 'order_payment':
        return 'Order Payment';
      case 'wallet_topup':
      case 'topup':
        return 'Wallet Top-up';
      case 'refund':
        return 'Refund';
      case 'subscription':
        return 'Subscription';
      default:
        return category.replaceAll('_', ' ').toUpperCase();
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
