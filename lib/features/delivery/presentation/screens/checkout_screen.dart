import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../models/cart_item.dart';
import '../../models/order_placement_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wallet_provider.dart';

// ─── Coupon model (replace with API model later) ──────────────────────────────

class _Coupon {
  final String code;
  final String title;
  final String description;
  final double discount;
  final String validTill;

  const _Coupon({
    required this.code,
    required this.title,
    required this.description,
    required this.discount,
    required this.validTill,
  });
}

// Mock coupons — swap for API response when ready
const List<_Coupon> _mockCoupons = [
  _Coupon(
    code: 'FITKHAO10',
    title: '₹10 Off',
    description: 'Get ₹10 off on any order',
    discount: 10.0,
    validTill: '31 May 2026',
  ),
  _Coupon(
    code: 'WELCOME20',
    title: '₹20 Off',
    description: 'Special welcome discount for new users',
    discount: 20.0,
    validTill: '30 Jun 2026',
  ),
  _Coupon(
    code: 'HEALTHY50',
    title: '₹50 Off',
    description: 'On orders above ₹300',
    discount: 50.0,
    validTill: '15 Jun 2026',
  ),
  _Coupon(
    code: 'SAVE30',
    title: '₹30 Off',
    description: 'Exclusive weekend offer',
    discount: 30.0,
    validTill: '31 May 2026',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedPaymentMethod = 'wallet'; // 'wallet' | 'gateway'
  final TextEditingController _instructionsController = TextEditingController();
  bool _isProcessing = false;

  // Coupon state
  _Coupon? _appliedCoupon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).loadWalletBalance();
    });
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);
    final walletState = ref.watch(walletProvider);

    const gst = 0.05;
    const platformCharge = 7.0;
    final itemTotal = totalPrice;
    final gstAmount = totalPrice * gst;
    final couponDiscount = _appliedCoupon?.discount ?? 0.0;
    final subTotal =
        (itemTotal + gstAmount + platformCharge - couponDiscount)
            .clamp(0.0, double.infinity);

    final couponBalance = walletState.wallet?.couponBalance ?? 0.0;
    final isWalletSufficient = couponBalance >= subTotal;

    // Auto-switch to gateway if wallet becomes insufficient
    if (!isWalletSufficient && _selectedPaymentMethod == 'wallet') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedPaymentMethod = 'gateway');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPaddingHorizontal,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSizes.spacing16),
                      _buildCartItems(cartItems),
                      const SizedBox(height: AppSizes.spacing20),
                      _buildCouponSection(),
                      const SizedBox(height: AppSizes.spacing20),
                      _buildPaymentMethodSection(
                        subTotal: subTotal,
                        couponBalance: couponBalance,
                        isWalletSufficient: isWalletSufficient,
                      ),
                      const SizedBox(height: AppSizes.spacing20),
                      _buildOrderSummary(
                        itemTotal: itemTotal,
                        gstAmount: gstAmount,
                        platformCharge: platformCharge,
                        couponDiscount: couponDiscount,
                        subTotal: subTotal,
                        couponBalance: couponBalance,
                      ),
                      const SizedBox(height: AppSizes.spacing20),
                      _buildInstructionsSection(),
                      const SizedBox(height: AppSizes.spacing24),
                      _buildConfirmOrderButton(
                        cartItems: cartItems,
                        subTotal: subTotal,
                        isWalletSufficient: isWalletSufficient,
                        walletState: walletState,
                      ),
                      const SizedBox(height: AppSizes.spacing32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
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
                  AppStrings.checkout,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  AppStrings.completeYourMealText,
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
        ],
      ),
    );
  }

  // ─── Cart Items ───────────────────────────────────────────────────────────

  Widget _buildCartItems(List<CartItem> cartItems) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cartItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
      itemBuilder: (_, index) => _buildCartItemCard(cartItems[index]),
    );
  }

  Widget _buildCartItemCard(CartItem cartItem) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: AppColors.primaryGreen,
          width: AppSizes.borderMedium,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            child: Image.network(
              cartItem.menuItem.imageUrl,
              width: AppSizes.icon60,
              height: AppSizes.icon60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: AppSizes.icon60,
                height: AppSizes.icon60,
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.restaurant,
                  size: AppSizes.icon32,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cartItem.quantity} × ${cartItem.menuItem.name}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize15,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  '${cartItem.menuItem.calories} ${AppStrings.kcal}',
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
                '₹${cartItem.totalPrice.toInt()}',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radius6),
                  border: Border.all(
                    color: AppColors.primaryGreen,
                    width: AppSizes.borderThin,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQuantityButton(
                      icon: Icons.remove,
                      onTap: () {
                        if (cartItem.quantity > 1) {
                          ref.read(cartProvider.notifier).updateQuantity(
                                cartItem.menuItem.id,
                                cartItem.quantity - 1,
                              );
                        } else {
                          ref
                              .read(cartProvider.notifier)
                              .removeItem(cartItem.menuItem.id);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacing12,
                      ),
                      child: Text(
                        '${cartItem.quantity}',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.primaryGreen,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                    _buildQuantityButton(
                      icon: Icons.add,
                      onTap: () =>
                          ref.read(cartProvider.notifier).updateQuantity(
                                cartItem.menuItem.id,
                                cartItem.quantity + 1,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing6),
        child:
            Icon(icon, size: AppSizes.icon16, color: AppColors.primaryGreen),
      ),
    );
  }

  // ─── Coupon Section ───────────────────────────────────────────────────────

  Widget _buildCouponSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.local_offer_outlined,
              size: AppSizes.icon20,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: AppSizes.spacing8),
            const Text(
              'Apply Coupon',
              style: TextStyle(
                fontSize: AppTypography.fontSize18,
                fontWeight: AppTypography.bold,
                color: AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: child,
            ),
          ),
          child: _appliedCoupon != null
              ? _buildAppliedTile(key: const ValueKey('applied'))
              : _buildSelectTile(key: const ValueKey('select')),
        ),
      ],
    );
  }

  /// Tappable tile shown when no coupon is selected.
  Widget _buildSelectTile({Key? key}) {
    return GestureDetector(
      key: key,
      onTap: _openCouponSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing16,
          vertical: AppSizes.spacing16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radius6),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                size: AppSizes.icon20,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a coupon',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  SizedBox(height: AppSizes.spacing2),
                  Text(
                    'Tap to view available offers',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: AppSizes.icon24,
            ),
          ],
        ),
      ),
    );
  }

  /// Green confirmation tile shown when a coupon is applied.
  Widget _buildAppliedTile({Key? key}) {
    final coupon = _appliedCoupon!;
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: AppSizes.icon16,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coupon Applied — ${coupon.title}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.primaryGreen,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacing6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radius4),
                      ),
                      child: Text(
                        coupon.code,
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize10,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.primaryGreen,
                          letterSpacing: 1.0,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing6),
                    Text(
                      '− ₹${coupon.discount.toStringAsFixed(2)} off',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.primaryGreen,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Change coupon
          GestureDetector(
            onTap: _openCouponSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing8,
                vertical: AppSizes.spacing6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radius6),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'Change',
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.primaryGreen,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          // Remove coupon
          GestureDetector(
            onTap: () => setState(() => _appliedCoupon = null),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.spacing6),
              decoration: BoxDecoration(
                color: AppColors.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radius6),
              ),
              child: const Icon(
                Icons.close,
                size: AppSizes.icon16,
                color: AppColors.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCouponSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CouponSheet(
        coupons: _mockCoupons,
        appliedCode: _appliedCoupon?.code,
        onApply: (coupon) {
          setState(() => _appliedCoupon = coupon);
          Navigator.of(context).pop();
        },
        onRemove: () {
          setState(() => _appliedCoupon = null);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ─── Payment Method ───────────────────────────────────────────────────────

  Widget _buildPaymentMethodSection({
    required double subTotal,
    required double couponBalance,
    required bool isWalletSufficient,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.primaryGreen,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        GestureDetector(
          onTap: isWalletSufficient
              ? () => setState(() => _selectedPaymentMethod = 'wallet')
              : null,
          child: Opacity(
            opacity: isWalletSufficient ? 1.0 : 0.45,
            child: _buildPaymentOption(
              icon: Icons.account_balance_wallet_outlined,
              title: 'FitKhao Wallet',
              subtitle: isWalletSufficient
                  ? 'Available: ₹${couponBalance.toStringAsFixed(2)}'
                  : 'Insufficient — ₹${couponBalance.toStringAsFixed(2)} available, ₹${subTotal.toStringAsFixed(2)} required',
              isSelected:
                  _selectedPaymentMethod == 'wallet' && isWalletSufficient,
              trailingWhenUnselected: isWalletSufficient
                  ? null
                  : const Icon(
                      Icons.lock_outline,
                      size: AppSizes.icon18,
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        GestureDetector(
          onTap: () => setState(() => _selectedPaymentMethod = 'gateway'),
          child: _buildPaymentOption(
            icon: Icons.credit_card_outlined,
            title: 'Pay Online',
            subtitle: 'UPI · Credit / Debit Card · Net Banking',
            isSelected: _selectedPaymentMethod == 'gateway',
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    Widget? trailingWhenUnselected,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryGreen.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
          width: isSelected ? AppSizes.borderMedium : AppSizes.borderThin,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGreen.withValues(alpha: 0.12)
                  : AppColors.textTertiary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppSizes.icon24,
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
            ),
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
                const SizedBox(height: AppSizes.spacing2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          if (isSelected)
            const Icon(
              Icons.check_circle,
              color: AppColors.primaryGreen,
              size: AppSizes.icon24,
            )
          else if (trailingWhenUnselected != null)
            trailingWhenUnselected
          else
            Container(
              width: AppSizes.icon20,
              height: AppSizes.icon20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.borderColor,
                  width: AppSizes.borderMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Order Summary ────────────────────────────────────────────────────────

  Widget _buildOrderSummary({
    required double itemTotal,
    required double gstAmount,
    required double platformCharge,
    required double couponDiscount,
    required double subTotal,
    required double couponBalance,
  }) {
    final balanceAfterOrder = couponBalance - subTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Summary',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.primaryGreen,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        Container(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                '${ref.watch(cartTotalItemsProvider)} × ${AppStrings.items}',
                '₹${itemTotal.toInt()}',
              ),
              const SizedBox(height: AppSizes.spacing8),
              _buildSummaryRow(
                'GST (5%)',
                '₹${gstAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: AppSizes.spacing8),
              _buildSummaryRow(
                'Platform Charge',
                '₹${platformCharge.toStringAsFixed(2)}',
              ),
              const SizedBox(height: AppSizes.spacing8),
              _buildSummaryRow(
                'Delivery Charge',
                'FREE',
                valueColor: AppColors.primaryGreen,
              ),
              if (_appliedCoupon != null) ...[
                const SizedBox(height: AppSizes.spacing8),
                _buildSummaryRow(
                  'Coupon (${_appliedCoupon!.code})',
                  '− ₹${couponDiscount.toStringAsFixed(2)}',
                  valueColor: AppColors.primaryGreen,
                ),
              ],
              const Divider(height: AppSizes.spacing20),
              _buildSummaryRow(
                'Total Payable',
                '₹${subTotal.toStringAsFixed(2)}',
                isBold: true,
              ),
              if (_selectedPaymentMethod == 'wallet') ...[
                const Divider(height: AppSizes.spacing20),
                _buildSummaryRow(
                  'Wallet Balance',
                  '₹${couponBalance.toStringAsFixed(2)}',
                ),
                const SizedBox(height: AppSizes.spacing8),
                _buildSummaryRow(
                  'Balance After Order',
                  '₹${balanceAfterOrder.toStringAsFixed(2)}',
                  isBold: true,
                  valueColor: balanceAfterOrder >= 0
                      ? AppColors.primaryGreen
                      : AppColors.errorColor,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    final weight = isBold ? AppTypography.semiBold : AppTypography.regular;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: weight,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: weight,
            color: valueColor ?? AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }

  // ─── Instructions ─────────────────────────────────────────────────────────

  Widget _buildInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Delivery Instructions',
              style: TextStyle(
                fontSize: AppTypography.fontSize18,
                fontWeight: AppTypography.bold,
                color: AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing8,
                vertical: AppSizes.spacing2,
              ),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radius4),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  fontSize: AppTypography.fontSize10,
                  fontWeight: AppTypography.medium,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),
        TextField(
          controller: _instructionsController,
          maxLines: 3,
          maxLength: 200,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
          decoration: InputDecoration(
            hintText:
                'e.g. Leave at door, call before delivery, no plastic bags…',
            hintStyle: const TextStyle(
              fontSize: AppTypography.fontSize13,
              color: AppColors.textTertiary,
              fontFamily: 'Lato',
            ),
            filled: true,
            fillColor: Colors.white,
            counterText: '',
            contentPadding: const EdgeInsets.all(AppSizes.spacing12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: AppSizes.borderMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Confirm Button ───────────────────────────────────────────────────────

  Widget _buildConfirmOrderButton({
    required List<CartItem> cartItems,
    required double subTotal,
    required bool isWalletSufficient,
    required WalletState walletState,
  }) {
    final canPlace = !_isProcessing &&
        cartItems.isNotEmpty &&
        (_selectedPaymentMethod == 'gateway' ||
            (_selectedPaymentMethod == 'wallet' && isWalletSufficient));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canPlace &&
            !_isProcessing &&
            cartItems.isNotEmpty &&
            _selectedPaymentMethod == 'wallet')
          Container(
            margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
            padding: const EdgeInsets.all(AppSizes.spacing12),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              border: Border.all(
                color: AppColors.errorColor.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.errorColor,
                  size: AppSizes.icon20,
                ),
                SizedBox(width: AppSizes.spacing8),
                Expanded(
                  child: Text(
                    'Wallet balance is insufficient. Please recharge or select Pay Online.',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.medium,
                      color: AppColors.errorColor,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: ElevatedButton(
            onPressed:
                canPlace ? () => _placeOrder(cartItems, subTotal) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              disabledBackgroundColor:
                  AppColors.textSecondary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
            ),
            child: _isProcessing || walletState.isLoading
                ? const SizedBox(
                    width: AppSizes.icon20,
                    height: AppSizes.icon20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    AppStrings.confirmOrder,
                    style: TextStyle(
                      fontSize: AppTypography.fontSize16,
                      fontWeight: AppTypography.semiBold,
                      color: Colors.white,
                      fontFamily: 'Lato',
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─── Order Placement ──────────────────────────────────────────────────────

  Future<void> _placeOrder(List<CartItem> cartItems, double subTotal) async {
    if (_selectedPaymentMethod == 'gateway') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Online payment coming soon!',
            style: TextStyle(fontFamily: 'Lato'),
          ),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final localStorage = await ref.read(localStorageProvider.future);
      final userPhone = localStorage.getUserPhone() ?? '';

      final authRepo = ref.read(authRepositoryProvider);
      final profileResponse = await authRepo.getProfile();

      Map<String, dynamic>? address;
      if (profileResponse['data'] != null) {
        final data = profileResponse['data'] as Map<String, dynamic>?;
        final user = data?['user'] as Map<String, dynamic>?;
        final profile = user?['profile'] as Map<String, dynamic>?;
        address = profile?['address'] as Map<String, dynamic>?;
        address ??= data?['address'] as Map<String, dynamic>?;
      }
      address ??= profileResponse['address'] as Map<String, dynamic>?;

      final deliveryAddress = DeliveryAddress(
        buildingName: address?['buildingName'] as String? ?? '',
        street: address?['street'] as String? ?? '',
        area: address?['area'] as String? ?? '',
        city: address?['city'] as String? ?? '',
        state: address?['state'] as String? ?? '',
        pincode: address?['pincode'] as String? ?? '000000',
        contactNumber: userPhone,
        latitude: (address?['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (address?['longitude'] as num?)?.toDouble() ?? 0.0,
        deliveryInstructions: _instructionsController.text.trim().isNotEmpty
            ? _instructionsController.text.trim()
            : null,
      );

      // Determine foodType: non-veg > eggetarian > vegan > veg
      String foodType = 'veg';
      for (final cartItem in cartItems) {
        final itemType = cartItem.menuItem.menuType.toLowerCase();
        if (itemType == 'nonveg' || itemType == 'non-veg') {
          foodType = 'non-veg';
          break;
        } else if (itemType == 'eggetarian' && foodType != 'non-veg') {
          foodType = 'eggetarian';
        } else if (itemType == 'vegan' && foodType == 'veg') {
          foodType = 'vegan';
        }
      }

      final orderItems = cartItems
          .map((c) =>
              OrderItem(foodItemId: c.menuItem.id, quantity: c.quantity))
          .toList();

      final instructions = _instructionsController.text.trim();

      final orderRepo = ref.read(orderRepositoryProvider);
      final orderResponse = await orderRepo.placeOrder(
        kitchenId: '69275ba5c538faaf25e2acd1',
        deliveryDate: DateTime.now().toIso8601String().substring(0, 10),
        deliverySlot: 'morning',
        items: orderItems,
        deliveryAddress: deliveryAddress,
        paymentMethod: 'wallet',
        orderType: 'single-meal',
        foodType: foodType,
        specialInstructions: instructions.isNotEmpty ? instructions : null,
      );

      if (!mounted) return;

      if (orderResponse.success && orderResponse.data != null) {
        await ref.read(walletProvider.notifier).loadWalletBalance();
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showSuccessDialog(orderResponse.data!.orderNumber);
      } else {
        setState(() => _isProcessing = false);
        _showErrorSnackbar(orderResponse.message);
      }
    } catch (e) {
      debugPrint('[CheckoutScreen] Error placing order: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorSnackbar('Failed to place order. Please try again.');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Lato')),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessDialog(String? orderNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: AppSizes.icon80,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: AppSizes.spacing24),
              const Text(
                'Order Placed Successfully!',
                style: TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing12),
              if (orderNumber != null)
                Text(
                  'Order #$orderNumber',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.primaryGreen,
                    fontFamily: 'Lato',
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: AppSizes.spacing8),
              const Text(
                'Your order has been confirmed and will be delivered soon.',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      ref.read(cartProvider.notifier).clearCart();
      Navigator.of(context).pop();
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }
}

// ─── Coupon Bottom Sheet ──────────────────────────────────────────────────────

class _CouponSheet extends StatelessWidget {
  final List<_Coupon> coupons;
  final String? appliedCode;
  final ValueChanged<_Coupon> onApply;
  final VoidCallback onRemove;

  const _CouponSheet({
    required this.coupons,
    required this.appliedCode,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F6F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.spacing12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacing20,
              AppSizes.spacing16,
              AppSizes.spacing16,
              AppSizes.spacing4,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.primaryGreen,
                  size: AppSizes.icon20,
                ),
                const SizedBox(width: AppSizes.spacing8),
                const Expanded(
                  child: Text(
                    'Available Coupons',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize18,
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Coupon list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.spacing16),
              shrinkWrap: true,
              itemCount: coupons.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSizes.spacing12),
              itemBuilder: (_, i) => _CouponCard(
                coupon: coupons[i],
                isApplied: coupons[i].code == appliedCode,
                onApply: () => onApply(coupons[i]),
                onRemove: onRemove,
              ),
            ),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + AppSizes.spacing8),
        ],
      ),
    );
  }
}

// ─── Single Coupon Card ───────────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  final _Coupon coupon;
  final bool isApplied;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  const _CouponCard({
    required this.coupon,
    required this.isApplied,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border(
          left: BorderSide(
            color: isApplied
                ? AppColors.primaryGreen
                : AppColors.primaryGreen.withValues(alpha: 0.4),
            width: 4,
          ),
          top: BorderSide(
            color: isApplied
                ? AppColors.primaryGreen.withValues(alpha: 0.3)
                : AppColors.borderColor,
          ),
          right: BorderSide(
            color: isApplied
                ? AppColors.primaryGreen.withValues(alpha: 0.3)
                : AppColors.borderColor,
          ),
          bottom: BorderSide(
            color: isApplied
                ? AppColors.primaryGreen.withValues(alpha: 0.3)
                : AppColors.borderColor,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: code + details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Code badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing8,
                      vertical: AppSizes.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      coupon.code,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize13,
                        fontWeight: AppTypography.bold,
                        color: AppColors.primaryGreen,
                        letterSpacing: 1.2,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  // Title
                  Text(
                    coupon.title,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize16,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing4),
                  // Description
                  Text(
                    coupon.description,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  // Valid till
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        size: AppSizes.icon12,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: AppSizes.spacing4),
                      Text(
                        'Valid till ${coupon.validTill}',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize10,
                          color: AppColors.textTertiary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            // Right: Apply / Remove
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isApplied) ...[
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primaryGreen,
                    size: AppSizes.icon24,
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  GestureDetector(
                    onTap: onRemove,
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.errorColor.withValues(alpha: 0.9),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ] else
                  TextButton(
                    onPressed: onApply,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      backgroundColor:
                          AppColors.primaryGreen.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacing12,
                        vertical: AppSizes.spacing8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radius6),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize13,
                        fontWeight: AppTypography.semiBold,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
