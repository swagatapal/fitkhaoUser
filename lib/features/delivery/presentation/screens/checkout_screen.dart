import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/razorpay_service.dart';
import '../../models/cart_item.dart';
import '../../models/coupon_model.dart';
import '../../models/order_placement_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/coupon_provider.dart';
import '../../providers/serviceability_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../../policy/models/app_constants_model.dart';
import '../../../policy/providers/app_constants_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Holds all data needed to place an order.
/// Populated before Razorpay opens so the success callback can submit
/// without re-fetching user/address data.
class _PendingOrderPayload {
  final String kitchenId;
  final List<OrderItem> items;
  final DeliveryAddress deliveryAddress;
  final String? specialInstructions;
  final List<String> couponIds;

  /// Set after a successful call to POST /razorpay/create-order.
  /// Used by the verify-payment call inside _onRazorpaySuccess.
  String? razorpayOrderId;

  /// Amount in paise — may be overwritten with the backend-computed value
  /// returned by POST /razorpay/create-order (covers discounts, taxes, etc.).
  int amountInPaise;

  _PendingOrderPayload({
    required this.kitchenId,
    required this.items,
    required this.deliveryAddress,
    this.specialInstructions,
    this.couponIds = const [],
    required this.amountInPaise,
  });
}

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
  CouponModel? _appliedCoupon;

  // Razorpay
  late final RazorpayService _razorpayService;
  _PendingOrderPayload? _pendingOrder;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(
      onSuccess: _onRazorpaySuccess,
      onFailure: _onRazorpayFailure,
      onExternalWallet: _onRazorpayExternalWallet,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).loadWalletBalance();
      final serviceState = ref.read(serviceabilityProvider);
      if (serviceState.kitchenId == null && !serviceState.isLoading) {
        ref.read(serviceabilityProvider.notifier).checkServiceability(
              latitude: 22.8671,
              longitude: 88.3674,
            );
      }
    });
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);
    final walletState = ref.watch(walletProvider);

    // Dynamic pricing from /api/app/constants — defaults to all-zero while
    // loading or on failure, so the checkout total is never wrong.
    final pricing = ref
            .watch(appConstantsProvider)
            .valueOrNull
            ?.pricing ??
        PricingConstants.defaults;

    final itemTotal = totalPrice;
    final platformCharge = pricing.platformFee;
    final deliveryCharge = pricing.deliveryCharge;
    final gstAmount = (itemTotal + platformCharge) * pricing.gstRate / 100;
    final couponDiscount = _appliedCoupon?.computeDiscount(itemTotal) ?? 0.0;
    final subTotal =
        (itemTotal + platformCharge + deliveryCharge + gstAmount - couponDiscount)
            .clamp(0.0, double.infinity);

    final couponBalance = walletState.wallet?.couponBalance ?? 0.0;
    final isWalletSufficient = couponBalance >= subTotal;

    // Auto-switch to gateway if wallet becomes insufficient
    if (!isWalletSufficient && _selectedPaymentMethod == 'wallet') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedPaymentMethod = 'gateway');
      });
    }

    // Auto-remove coupon when cart total drops below its minimum order amount
    if (_appliedCoupon != null &&
        _appliedCoupon!.minOrderAmount > 0 &&
        itemTotal < _appliedCoupon!.minOrderAmount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _appliedCoupon = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Coupon removed — cart total is below the minimum order amount.',
              style: TextStyle(fontFamily: 'Lato'),
            ),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
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
                        gstRate: pricing.gstRate,
                        gstAmount: gstAmount,
                        platformCharge: platformCharge,
                        deliveryCharge: deliveryCharge,
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
                  'Coupon Applied — ${coupon.name}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.primaryGreen,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing2),
                Wrap(
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
                      '− ${coupon.discountLabel}',
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
    ref.read(couponProvider.notifier).loadCoupons();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CouponSheet(
        appliedCode: _appliedCoupon?.code,
        itemTotal: ref.read(cartTotalPriceProvider),
        onApply: (coupon) {
          final itemTotal = ref.read(cartTotalPriceProvider);
          if (coupon.minOrderAmount > 0 && itemTotal < coupon.minOrderAmount) {
            Navigator.of(context).pop();
            _showErrorSnackbar(
              'Minimum order of ₹${coupon.minOrderAmount.toInt()} required for this coupon.',
            );
            return;
          }
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
    required double gstRate,
    required double gstAmount,
    required double platformCharge,
    required double deliveryCharge,
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
              // Item total
              _buildSummaryRow(
                '${ref.watch(cartTotalItemsProvider)} × ${AppStrings.items}',
                '₹${itemTotal.toInt()}',
              ),

              // Platform fee — shown only when non-zero
              if (platformCharge > 0) ...[
                const SizedBox(height: AppSizes.spacing8),
                _buildSummaryRow(
                  'Platform Fee',
                  '₹${platformCharge.toStringAsFixed(2)}',
                ),
              ],

              // GST — shown only when non-zero; label includes live rate
              if (gstAmount > 0) ...[
                const SizedBox(height: AppSizes.spacing8),
                _buildSummaryRow(
                  'GST (${gstRate.toStringAsFixed(0)}%)',
                  '₹${gstAmount.toStringAsFixed(2)}',
                ),
              ],

              // Delivery — always visible; FREE when zero
              const SizedBox(height: AppSizes.spacing8),
              _buildSummaryRow(
                'Delivery Charge',
                deliveryCharge > 0
                    ? '₹${deliveryCharge.toStringAsFixed(2)}'
                    : 'FREE',
                valueColor: deliveryCharge > 0
                    ? null
                    : AppColors.primaryGreen,
              ),

              // Coupon discount
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

  /// Builds the common delivery payload, then branches:
  /// • wallet  → POST /api/orders/place directly
  /// • gateway → POST /razorpay/create-order → open Razorpay SDK
  Future<void> _placeOrder(List<CartItem> cartItems, double subTotal) async {
    final kitchenId = ref.read(serviceabilityProvider).kitchenId;
    if (kitchenId == null || kitchenId.isEmpty) {
      _showErrorSnackbar('Service not available in your area. Please try again.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final localStorage = await ref.read(localStorageProvider.future);
      final userPhone = localStorage.getUserPhone() ?? '';
      final userName = localStorage.getUserName() ?? 'FitKhao User';
      final userEmail = localStorage.getUserEmail() ?? '';

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

      final instructions = _instructionsController.text.trim();

      final deliveryAddress = DeliveryAddress(
        buildingName: address?['buildingName'] as String? ?? '',
        street: address?['street'] as String? ?? '',
        pincode: address?['pincode'] as String? ?? '000000',
        contactNumber: userPhone,
        latitude: (address?['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (address?['longitude'] as num?)?.toDouble() ?? 0.0,
        deliveryInstructions: instructions.isNotEmpty ? instructions : null,
      );

      final orderItems = cartItems
          .map((c) => OrderItem(dishId: c.menuItem.id, quantity: c.quantity, dishServing: 1))
          .toList();

      final couponIds = _appliedCoupon != null ? [_appliedCoupon!.id] : <String>[];

      _pendingOrder = _PendingOrderPayload(
        kitchenId: kitchenId,
        items: orderItems,
        deliveryAddress: deliveryAddress,
        specialInstructions: instructions.isNotEmpty ? instructions : null,
        couponIds: couponIds,
        amountInPaise: (subTotal * 100).round(),
      );

      if (_selectedPaymentMethod == 'wallet') {
        await _executeWalletOrderPlacement();
      } else {
        await _initiateRazorpayFlow(
          cartItems: cartItems,
          userName: userName,
          userEmail: userEmail,
          userPhone: userPhone,
        );
      }
    } catch (e) {
      debugPrint('[CheckoutScreen] Error preparing order: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _pendingOrder = null;
      _showErrorSnackbar('Failed to prepare order. Please try again.');
    }
  }

  /// Wallet path — POST /api/orders/place and show result.
  Future<void> _executeWalletOrderPlacement() async {
    final pending = _pendingOrder;
    if (pending == null) {
      _showErrorSnackbar('Order data missing. Please try again.');
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final response = await orderRepo.placeOrder(
        kitchenId: pending.kitchenId,
        items: pending.items,
        deliveryAddress: pending.deliveryAddress,
        paymentMethod: 'wallet',
        specialInstructions: pending.specialInstructions,
      );

      _pendingOrder = null;
      if (!mounted) return;

      if (response.success && response.data != null) {
        await ref.read(walletProvider.notifier).loadWalletBalance();
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showSuccessDialog(response.data!.orderNumber);
      } else {
        setState(() => _isProcessing = false);
        _showErrorSnackbar(response.message.isNotEmpty
            ? response.message
            : 'Failed to place order. Please try again.');
      }
    } catch (e) {
      debugPrint('[CheckoutScreen] Wallet order error: $e');
      _pendingOrder = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorSnackbar('Failed to place order. Please try again.');
    }
  }

  /// Gateway path — create Razorpay order on backend, then open the SDK.
  Future<void> _initiateRazorpayFlow({
    required List<CartItem> cartItems,
    required String userName,
    required String userEmail,
    required String userPhone,
  }) async {
    final pending = _pendingOrder;
    if (pending == null) return;

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final createResponse = await orderRepo.createRazorpayOrder(
        pendingOrderData: RazorpayPendingOrderData(
          kitchenId: pending.kitchenId,
          items: pending.items,
          deliveryAddress: pending.deliveryAddress,
          specialInstructions: pending.specialInstructions,
          couponIds: pending.couponIds,
        ),
        purpose: 'order_food',
      );

      if (!createResponse.success || createResponse.data == null) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _pendingOrder = null;
        _showErrorSnackbar(createResponse.message.isNotEmpty
            ? createResponse.message
            : 'Could not initiate payment. Please try again.');
        return;
      }

      final orderData = createResponse.data!;
      pending.razorpayOrderId = orderData.razorpayOrderId;
      pending.amountInPaise = orderData.amountInPaise > 0
          ? orderData.amountInPaise
          : pending.amountInPaise;

      debugPrint(
        '[CheckoutScreen] Razorpay order created — '
        'orderId=${orderData.razorpayOrderId} amount=${orderData.amountInPaise}',
      );

      if (!mounted) return;
      // Stop the spinner — Razorpay SDK renders its own loading UI.
      setState(() => _isProcessing = false);

      _razorpayService.open(
        RazorpayPaymentConfig(
          amountInPaise: pending.amountInPaise,
          orderId: orderData.razorpayOrderId,
          description:
              'FitKhao order — ${cartItems.length} item${cartItems.length > 1 ? 's' : ''}',
          customerName: userName,
          customerEmail: userEmail,
          customerContact: userPhone,
        ),
      );
    } catch (e) {
      debugPrint('[CheckoutScreen] createRazorpayOrder error: $e');
      _pendingOrder = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorSnackbar('Payment initiation failed. Please try again.');
    }
  }

  // ─── Razorpay Callbacks ───────────────────────────────────────────────────

  /// Called by the Razorpay SDK after the user completes payment.
  /// Calls POST /razorpay/verify-payment to confirm and finalise the order.
  void _onRazorpaySuccess(
    String paymentId,
    String? sdkOrderId,
    String? signature,
  ) {
    debugPrint(
      '[CheckoutScreen] Razorpay success — '
      'paymentId=$paymentId orderId=$sdkOrderId',
    );
    _verifyRazorpayPayment(
      paymentId: paymentId,
      sdkOrderId: sdkOrderId,
      signature: signature,
    );
  }

  Future<void> _verifyRazorpayPayment({
    required String paymentId,
    required String? sdkOrderId,
    required String? signature,
  }) async {
    final pending = _pendingOrder;
    // Prefer the order ID stored from the create-order response; fall back to
    // what the SDK echoes back in case of any mismatch.
    final razorpayOrderId =
        (pending?.razorpayOrderId?.isNotEmpty == true)
            ? pending!.razorpayOrderId!
            : (sdkOrderId ?? '');

    if (razorpayOrderId.isEmpty) {
      debugPrint('[CheckoutScreen] verifyPayment: razorpayOrderId is empty');
      _pendingOrder = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorSnackbar('Payment verification failed. Please contact support.');
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final verifyResponse = await orderRepo.verifyRazorpayPayment(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature ?? '',
        purpose: 'order_food',
      );

      _pendingOrder = null;
      if (!mounted) return;

      if (verifyResponse.success) {
        await ref.read(walletProvider.notifier).loadWalletBalance();
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showSuccessDialog(verifyResponse.data?.orderNumber);
      } else {
        setState(() => _isProcessing = false);
        _showErrorSnackbar(verifyResponse.message.isNotEmpty
            ? verifyResponse.message
            : 'Payment verification failed. Please contact support.');
      }
    } catch (e) {
      debugPrint('[CheckoutScreen] verifyRazorpayPayment error: $e');
      _pendingOrder = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorSnackbar('Payment verification failed. Please try again.');
    }
  }

  void _onRazorpayFailure(int code, String message) {
    debugPrint('[CheckoutScreen] Razorpay failure — code=$code msg=$message');
    _pendingOrder = null;
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showErrorSnackbar(message);
  }

  void _onRazorpayExternalWallet(String walletName) {
    debugPrint('[CheckoutScreen] Razorpay external wallet — $walletName');
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

class _CouponSheet extends ConsumerWidget {
  final String? appliedCode;
  final double itemTotal;
  final ValueChanged<CouponModel> onApply;
  final VoidCallback onRemove;

  const _CouponSheet({
    required this.appliedCode,
    required this.itemTotal,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponState = ref.watch(couponProvider);

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

          // Body: loading / error / list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: _buildBody(context, couponState, itemTotal),
          ),

          SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppSizes.spacing8,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, CouponState state, double itemTotal) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (state.error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: AppSizes.icon48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      );
    }

    if (state.coupons.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: AppSizes.icon48,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSizes.spacing12),
            Text(
              'No coupons available right now',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      shrinkWrap: true,
      itemCount: state.coupons.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
      itemBuilder: (_, i) {
        final coupon = state.coupons[i];
        final eligible = coupon.minOrderAmount <= 0 || itemTotal >= coupon.minOrderAmount;
        return _CouponCard(
          coupon: coupon,
          isApplied: coupon.code == appliedCode,
          isEligible: eligible,
          onApply: eligible ? () => onApply(coupon) : null,
          onRemove: onRemove,
        );
      },
    );
  }
}

// ─── Single Coupon Card ───────────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  final CouponModel coupon;
  final bool isApplied;
  final bool isEligible;
  final VoidCallback? onApply;
  final VoidCallback onRemove;

  const _CouponCard({
    required this.coupon,
    required this.isApplied,
    required this.isEligible,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isFlat = coupon.discountType == CouponDiscountType.flat;

    return Opacity(
      opacity: isEligible ? 1.0 : 0.5,
      child: InkWell(
        onTap:onApply,
        child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: isApplied
                ? AppColors.primaryGreen.withValues(alpha: 0.4)
                : AppColors.borderColor,
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
                    // Code badge + discount-type chip
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spacing8,
                            vertical: AppSizes.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radius4),
                            border: Border.all(
                              color:
                                  AppColors.primaryGreen.withValues(alpha: 0.3),
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
                        const SizedBox(width: AppSizes.spacing6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spacing6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isFlat
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF3E0),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radius4),
                          ),
                          child: Text(
                            isFlat ? 'FLAT' : '%OFF',
                            style: TextStyle(
                              fontSize: AppTypography.fontSize10,
                              fontWeight: AppTypography.bold,
                              color: isFlat
                                  ? AppColors.primaryGreen
                                  : const Color(0xFFE65100),
                              fontFamily: 'Lato',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spacing8),
                    // Discount headline
                    Text(
                      coupon.discountLabel,
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
                    const SizedBox(height: AppSizes.spacing6),
                    // Min order condition
                    if (coupon.minOrderAmount > 0)
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: AppSizes.icon12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: AppSizes.spacing4),
                          Text(
                            'Min order ₹${coupon.minOrderAmount.toInt()}',
                            style: const TextStyle(
                              fontSize: AppTypography.fontSize10,
                              color: AppColors.textTertiary,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSizes.spacing4),
                    // Expiry
                    if (coupon.formattedExpiry.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_outlined,
                            size: AppSizes.icon12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: AppSizes.spacing4),
                          Text(
                            'Valid till ${coupon.formattedExpiry}',
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
                          borderRadius: BorderRadius.circular(AppSizes.radius6),
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
            ),
      ),
    );
  }
}
