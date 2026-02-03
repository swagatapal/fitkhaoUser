import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../shared/widgets/logo_widget.dart';
import '../../models/cart_item.dart';
import '../../models/order_placement_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wallet_provider.dart';
import '../widgets/order_confirmation_modal.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedDeliveryDate = 'Tomorrow';

  @override
  void initState() {
    super.initState();
    // Load wallet data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).loadWalletBalance();

      // If ordering time has passed, automatically select "Day After Tomorrow"
      if (_isOrderingTimePassed()) {
        setState(() {
          _selectedDeliveryDate = AppStrings.dayAfterTomorrow;
        });
      }
    });
  }

  /// Check if current time is after 10 PM (22:00)
  bool _isOrderingTimePassed() {
    final now = DateTime.now();
    final orderDeadline = DateTime(now.year, now.month, now.day, 22, 0); // 10 PM
    return now.isAfter(orderDeadline);
  }


  /// Check if order can be placed
  /// Requirements:
  /// 1. Must have active subscription
  /// 2. Subtotal must be less than or equal to coupon balance
  /// 3. If after 10 PM, can only order for Day After Tomorrow
  bool _canPlaceOrder(double subTotal, WalletState walletState) {
    final hasActiveSubscription = walletState.hasActiveSubscription;
    final couponBalance = walletState.wallet?.couponBalance ?? 0.0;
    final hasSufficientBalance = subTotal <= couponBalance;
    final isOrderingTimePassed = _isOrderingTimePassed();

    // If after 10 PM, only allow orders for Day After Tomorrow
    final isValidDeliveryDate = !isOrderingTimePassed ||
        _selectedDeliveryDate == AppStrings.dayAfterTomorrow;

    debugPrint('[CheckoutScreen] Can place order check:');
    debugPrint('  - Active subscription: $hasActiveSubscription');
    debugPrint('  - Coupon balance: ₹$couponBalance');
    debugPrint('  - Subtotal: ₹$subTotal');
    debugPrint('  - Sufficient balance: $hasSufficientBalance');
    debugPrint('  - Ordering time passed: $isOrderingTimePassed');
    debugPrint('  - Selected delivery date: $_selectedDeliveryDate');
    debugPrint('  - Valid delivery date: $isValidDeliveryDate');
    debugPrint('  - Can place order: ${hasActiveSubscription && hasSufficientBalance && isValidDeliveryDate}');

    return hasActiveSubscription && hasSufficientBalance && isValidDeliveryDate;
  }

  /// Get error message when order cannot be placed
  String _getOrderValidationMessage(double subTotal, WalletState walletState) {
    final hasActiveSubscription = walletState.hasActiveSubscription;
    final couponBalance = walletState.wallet?.couponBalance ?? 0.0;
    final hasSufficientBalance = subTotal <= couponBalance;
    final isOrderingTimePassed = _isOrderingTimePassed();

    if (isOrderingTimePassed && _selectedDeliveryDate == AppStrings.tomorrow) {
      return 'Orders for tomorrow are closed after 10:00 PM. Please select Day After Tomorrow.';
    } else if (!hasActiveSubscription && !hasSufficientBalance) {
      return 'No active subscription and insufficient coupon balance';
    } else if (!hasActiveSubscription) {
      return 'No active subscription. Please subscribe to place orders.';
    } else if (!hasSufficientBalance) {
      return 'Insufficient coupon balance. Required: ₹${subTotal.toStringAsFixed(2)}, Available: ₹${couponBalance.toStringAsFixed(2)}';
    }
    return '';
  }

  /// Format date string to readable format
  String _formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      // If parsing fails, return the original string
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);
    final walletState = ref.watch(walletProvider);

    // Calculate charges
    final gst = totalPrice * 0.05; // 5% GST
    final platformCharge = 7.0;
    final deliveryCharge = 0.0;
    final subTotal = totalPrice + gst + platformCharge + deliveryCharge;

    // Get coupon balance from wallet
    final couponBalance = walletState.wallet?.couponBalance ?? 0.0;
    final deducted = subTotal > couponBalance ? couponBalance : subTotal;
    final remainingBalance = couponBalance - deducted;

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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFitKhaoLogo(),
                          const SizedBox(width: AppSizes.spacing12),
                          Expanded(
                            child: _buildOrderTimeAlert(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.spacing16),
                      _buildCartItems(cartItems),
                      const SizedBox(height: AppSizes.spacing20),
                      _buildDeliveryDateSection(),
                      const SizedBox(height: AppSizes.spacing20),
                      _buildPaymentSummary(
                        totalPrice,
                        gst,
                        platformCharge,
                        deliveryCharge,
                        subTotal,
                        deducted,
                        remainingBalance,
                      ),
                      const SizedBox(height: AppSizes.spacing24),
                      _buildConfirmOrderButton(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.checkout,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const Text(
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
          // CircleAvatar(
          //   radius: AppSizes.spacing24,
          //   backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          //   backgroundImage: const NetworkImage(
          //     "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTFcyssMbcvEkMiCDu8zrO9VuN-Yy1aW1vycA&s",
          //   ),
          //   onBackgroundImageError: (exception, stackTrace) {},
          //   child: Container(
          //     decoration: BoxDecoration(
          //       shape: BoxShape.circle,
          //       border: Border.all(
          //         color: AppColors.primaryGreen.withValues(alpha: 0.3),
          //         width: AppSizes.borderThin,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildFitKhaoLogo() {
    return LogoWidget();
  }

  Widget _buildOrderTimeAlert() {
    final now = DateTime.now();
    final orderDeadline = DateTime(now.year, now.month, now.day, 22, 0); // 10 PM
    final isTimePassed = now.isAfter(orderDeadline);
    final difference = orderDeadline.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);

    // Determine urgency level
    final isUrgent = difference.inMinutes <= 60 && !isTimePassed; // Less than 1 hour
    final isWarning = difference.inHours <= 3 && !isTimePassed; // Less than 3 hours

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    Color iconColor;
    IconData icon;
    String message;
    String timeText;

    if (isTimePassed) {
      backgroundColor = const Color(0xFFFF9800).withValues(alpha: 0.1);
      borderColor = const Color(0xFFFF9800);
      textColor = const Color(0xFFFF9800);
      iconColor = const Color(0xFFFF9800);
      icon = Icons.info_outline;
      message = 'Tomorrow Orders Closed';
      timeText = 'Day After Tomorrow orders available';
    } else if (isUrgent) {
      backgroundColor = const Color(0xFFFF6B6B).withValues(alpha: 0.15);
      borderColor = const Color(0xFFFF6B6B);
      textColor = const Color(0xFFD32F2F);
      iconColor = const Color(0xFFFF6B6B);
      icon = Icons.access_time_filled;
      message = 'Order Soon!';
      timeText = hours > 0 ? '$hours hr $minutes min left' : '$minutes min left';
    } else if (isWarning) {
      backgroundColor = const Color(0xFFFF9800).withValues(alpha: 0.1);
      borderColor = const Color(0xFFFF9800);
      textColor = const Color(0xFFFF9800);
      iconColor = const Color(0xFFFF9800);
      icon = Icons.schedule;
      message = 'Place Order Before 10 PM';
      timeText = '$hours hr $minutes min left';
    } else {
      backgroundColor = AppColors.primaryGreen.withValues(alpha: 0.1);
      borderColor = AppColors.primaryGreen;
      textColor = AppColors.primaryGreen;
      iconColor = AppColors.primaryGreen;
      icon = Icons.check_circle_outline;
      message = 'Place Order Before 10 PM';
      timeText = '$hours hr $minutes min left';
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            backgroundColor,
            backgroundColor.withValues(alpha: backgroundColor.a * 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        // boxShadow: [
        //   BoxShadow(
        //     color: borderColor.withValues(alpha: 0.2),
        //     blurRadius: 8,
        //     offset: const Offset(0, 2),
        //   ),
        // ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing4),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSizes.radius6),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: AppSizes.icon16,
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize10,
                    fontWeight: AppTypography.semiBold,
                    color: textColor,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing2),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.extraBold,
                    color: textColor.withValues(alpha: 0.8),
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          if (isUrgent && !isTimePassed)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing8,
                vertical: AppSizes.spacing4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B),
                borderRadius: BorderRadius.circular(AppSizes.radius12),
              ),
              child: const Text(
                'URGENT',
                style: TextStyle(
                  fontSize: AppTypography.fontSize10,
                  fontWeight: AppTypography.bold,
                  color: Colors.white,
                  fontFamily: 'Lato',
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildCartItems(List<CartItem> cartItems) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cartItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSizes.spacing12),
      itemBuilder: (context, index) {
        return _buildCartItemCard(cartItems[index]);
      },
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
          // Food Image
          Container(
            width: AppSizes.icon60,
            height: AppSizes.icon60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              child: Image.network(
                cartItem.menuItem.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.restaurant,
                      size: AppSizes.icon32,
                      color: AppColors.primaryGreen,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),

          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cartItem.quantity} x ${cartItem.menuItem.name}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize16,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  cartItem.menuItem.category,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  '${cartItem.menuItem.calories} ${AppStrings.kcal}',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    fontWeight: AppTypography.regular,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),

          // Quantity Controls
          Column(
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
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
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
                          ref.read(cartProvider.notifier).removeItem(
                            cartItem.menuItem.id,
                          );
                        }
                      },
                    ),
                    Container(
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
                      onTap: () {
                        ref.read(cartProvider.notifier).updateQuantity(
                          cartItem.menuItem.id,
                          cartItem.quantity + 1,
                        );
                      },
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
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing4),
        child: Icon(
          icon,
          size: AppSizes.icon16,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildDeliveryDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.selectDeliveryDate,
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.primaryGreen,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        Row(
          children: [
            Expanded(
              child: _buildDeliveryDateButton(AppStrings.tomorrow),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: _buildDeliveryDateButton(AppStrings.dayAfterTomorrow),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),
        const Text(
          AppStrings.orderDeliveredBetween,
          style: TextStyle(
            fontSize: AppTypography.fontSize12,
            fontWeight: AppTypography.regular,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryDateButton(String date) {
    final isSelected = _selectedDeliveryDate == date;
    final isOrderingTimePassed = _isOrderingTimePassed();
    final isTomorrowBlocked = date == AppStrings.tomorrow && isOrderingTimePassed;

    return GestureDetector(
      onTap: isTomorrowBlocked
          ? null
          : () {
              setState(() {
                _selectedDeliveryDate = date;
              });
            },
      child: Opacity(
        opacity: isTomorrowBlocked ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
          decoration: BoxDecoration(
            color: isTomorrowBlocked
                ? AppColors.textSecondary.withValues(alpha: 0.1)
                : (isSelected ? AppColors.primaryGreen : Colors.white),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            border: Border.all(
              color: isTomorrowBlocked
                  ? AppColors.textSecondary.withValues(alpha: 0.3)
                  : AppColors.primaryGreen,
              width: AppSizes.borderMedium,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isTomorrowBlocked)
                  const Padding(
                    padding: EdgeInsets.only(right: AppSizes.spacing8),
                    child: Icon(
                      Icons.lock,
                      size: AppSizes.icon16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: isTomorrowBlocked
                        ? AppColors.textSecondary
                        : (isSelected ? Colors.white : AppColors.primaryGreen),
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummary(
    double totalPrice,
    double gst,
    double platformCharge,
    double deliveryCharge,
    double subTotal,
    double deducted,
    double remainingBalance,
      )
  {
    final walletState = ref.watch(walletProvider);
    final wallet = walletState.wallet;
    final hasActiveSubscription = walletState.hasActiveSubscription;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.paymentSummary,
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.primaryGreen,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),

        // Subscription Status Indicator
        Container(
          padding: const EdgeInsets.all(AppSizes.spacing12),
          margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
          decoration: BoxDecoration(
            color: hasActiveSubscription
                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                : AppColors.errorColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            border: Border.all(
              color: hasActiveSubscription
                  ? AppColors.primaryGreen
                  : AppColors.errorColor,
              width: AppSizes.borderMedium,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasActiveSubscription
                    ? Icons.check_circle
                    : Icons.cancel,
                color: hasActiveSubscription
                    ? AppColors.primaryGreen
                    : AppColors.errorColor,
                size: AppSizes.icon24,
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasActiveSubscription
                          ? 'Active Subscription'
                          : 'No Active Subscription',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: hasActiveSubscription
                            ? AppColors.primaryGreen
                            : AppColors.errorColor,
                        fontFamily: 'Lato',
                      ),
                    ),
                    if (walletState.subscription != null) ...[
                      const SizedBox(height: AppSizes.spacing4),
                      Text(
                        hasActiveSubscription
                            ? 'Valid till ${_formatDateString(walletState.subscription!.endDate)} (${walletState.subscription!.remainingDays} days left)'
                            : 'Subscribe to place orders',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          fontWeight: AppTypography.regular,
                          color: hasActiveSubscription
                              ? AppColors.textSecondary
                              : AppColors.errorColor,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Item total, GST, Platform Charge, and Delivery Charge
        Container(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            border: Border.all(
              color: AppColors.borderColor,
              width: AppSizes.borderMedium,
            ),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                '${ref.watch(cartTotalItemsProvider)} x ${AppStrings.items}',
                '₹${totalPrice.toInt()}',
              ),
              const SizedBox(height: AppSizes.spacing8),
              _buildSummaryRow(
                'GST (5%)',
                '₹${gst.toStringAsFixed(2)}',
              ),
              const SizedBox(height: AppSizes.spacing8),
              _buildSummaryRow(
                'Platform Charge',
                '₹${platformCharge.toStringAsFixed(2)}',
              ),
              const SizedBox(height: AppSizes.spacing8),
              _buildSummaryRow(
                'Delivery Charge',
                '₹${deliveryCharge.toStringAsFixed(2)}',
              ),
              const Divider(height: AppSizes.spacing20),
              _buildSummaryRow(
                AppStrings.subTotal,
                '₹${subTotal.toStringAsFixed(2)}',
                isBold: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSizes.spacing12),

        // Coupon Balance
        Container(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            border: Border.all(
              color: AppColors.borderColor,
              width: AppSizes.borderMedium,
            ),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                AppStrings.couponBalance,
                '₹${wallet?.couponBalance.toStringAsFixed(2)}',
              ),
              const SizedBox(height: AppSizes.spacing8),
              _buildSummaryRow(
                AppStrings.deducted,
                '₹${deducted.toStringAsFixed(2)}',
              ),
              const Divider(height: AppSizes.spacing20),
              _buildSummaryRow(
                AppStrings.remainingBalance,
                '₹${((wallet?.couponBalance)!-deducted).toStringAsFixed(2)}',
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: isBold ? AppTypography.semiBold : AppTypography.regular,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: isBold ? AppTypography.semiBold : AppTypography.regular,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmOrderButton() {
    final cartItems = ref.watch(cartProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);
    final walletState = ref.watch(walletProvider);

    // Calculate total with GST, platform charge, and delivery charge
    final gst = totalPrice * 0.05; // 5% GST
    final platformCharge = 7.0;
    final deliveryCharge = 0.0;
    final grandTotal = totalPrice + gst + platformCharge + deliveryCharge;

    // Check if order can be placed
    final canPlaceOrder = _canPlaceOrder(grandTotal, walletState);
    final validationMessage = _getOrderValidationMessage(grandTotal, walletState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Show validation message if button is disabled
        if (!canPlaceOrder && cartItems.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radius8),
              border: Border.all(
                color: AppColors.errorColor.withValues(alpha: 0.3),
                width: AppSizes.borderThin,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.errorColor,
                  size: AppSizes.icon20,
                ),
                const SizedBox(width: AppSizes.spacing8),
                Expanded(
                  child: Text(
                    validationMessage,
                    style: const TextStyle(
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
        ],

        // Confirm Order Button
        SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: ElevatedButton(
            onPressed: (cartItems.isEmpty || !canPlaceOrder)
                ? null
                : () {
                    _showOrderConfirmationModal(cartItems, grandTotal);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
            ),
            child: walletState.isLoading
                ? const SizedBox(
                    height: AppSizes.icon20,
                    width: AppSizes.icon20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  Future<void> _showOrderConfirmationModal(
    List<CartItem> cartItems,
    double totalAmount,
  ) async {
    try {
      // Get user data from local storage and profile
      final localStorage = await ref.read(localStorageProvider.future);
      final userPhone = localStorage.getUserPhone() ?? '9800072183';

      // Fetch user profile to get address details from API
      debugPrint('[CheckoutScreen] Fetching user profile for delivery address...');
      final authRepo = ref.read(authRepositoryProvider);
      final profileResponse = await authRepo.getProfile();

      // Debug: Log full response structure
      debugPrint('[CheckoutScreen] Full profile response: $profileResponse');
      debugPrint('[CheckoutScreen] Response keys: ${profileResponse.keys.toList()}');

      // Try to parse address from different possible structures
      Map<String, dynamic>? address;

      // Try structure: response['data']['user']['profile']['address']
      if (profileResponse['data'] != null) {
        final profileData = profileResponse['data'] as Map<String, dynamic>?;
        debugPrint('[CheckoutScreen] Profile data: $profileData');
        debugPrint('[CheckoutScreen] Profile data keys: ${profileData?.keys.toList()}');

        if (profileData != null && profileData['user'] != null) {
          final user = profileData['user'] as Map<String, dynamic>?;
          debugPrint('[CheckoutScreen] User object: $user');

          if (user != null && user['profile'] != null) {
            final profile = user['profile'] as Map<String, dynamic>?;
            debugPrint('[CheckoutScreen] Profile object: $profile');
            debugPrint('[CheckoutScreen] Profile object keys: ${profile?.keys.toList()}');
            address = profile?['address'] as Map<String, dynamic>?;
          }
        } else if (profileData != null && profileData['profile'] != null) {
          // Try structure: response['data']['profile']['address']
          final profile = profileData['profile'] as Map<String, dynamic>?;
          debugPrint('[CheckoutScreen] Profile object: $profile');
          debugPrint('[CheckoutScreen] Profile object keys: ${profile?.keys.toList()}');
          address = profile?['address'] as Map<String, dynamic>?;
        } else if (profileData != null && profileData['address'] != null) {
          // Try structure: response['data']['address']
          address = profileData['address'] as Map<String, dynamic>?;
        }
      } else if (profileResponse['profile'] != null) {
        // Try structure: response['profile']['address']
        final profile = profileResponse['profile'] as Map<String, dynamic>?;
        address = profile?['address'] as Map<String, dynamic>?;
      } else if (profileResponse['address'] != null) {
        // Try structure: response['address']
        address = profileResponse['address'] as Map<String, dynamic>?;
      }

      debugPrint('[CheckoutScreen] Extracted address: $address');
      debugPrint('[CheckoutScreen] Address keys: ${address?.keys.toList()}');

      // Extract address fields from profile API response
      final deliveryAddress = DeliveryAddress(
        buildingName: address?['buildingName'] as String? ?? 'N/A',
        street: address?['street'] as String? ?? 'N/A',
        area: address?['area'] as String? ?? 'N/A',
        city: address?['city'] as String? ?? '',
        state: address?['state'] as String? ?? '',
        //pincode: address?['pincode'] as String? ?? '000000',
        pincode: '560034',
        contactNumber: userPhone,
        latitude: (address?['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (address?['longitude'] as num?)?.toDouble() ?? 0.0,
      );

      debugPrint('[CheckoutScreen] Using delivery address: ${deliveryAddress.buildingName}, ${deliveryAddress.street}, ${deliveryAddress.city}');

      if (!mounted) return;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => OrderConfirmationModal(
          deliveryDate: _selectedDeliveryDate == 'Tomorrow'
              ? DateTime.now().add(const Duration(days: 1)).toIso8601String()
              : DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          cartItems: cartItems,
          totalAmount: totalAmount,
          deliveryAddress: deliveryAddress,
        ),
      );

      debugPrint('[CheckoutScreen] Order confirmation result: $result');

      if (result != null && result['success'] == true && mounted) {
        debugPrint('[CheckoutScreen] Payment successful! Showing success dialog and clearing cart...');
        _showSuccessDialog(result['orderNumber'], result['payment']);
      } else {
        debugPrint('[CheckoutScreen] Order was not successful or result is null');
      }
    } catch (e) {
      debugPrint('[CheckoutScreen] Error fetching profile for delivery address: $e');

      // Show error to user
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to fetch delivery address from profile. Please update your profile with address details.'),
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 4),
        ),
      );

      // Fallback to user phone and default address if profile fetch fails
      final localStorage = await ref.read(localStorageProvider.future);
      final userPhone = localStorage.getUserPhone() ?? '9800072183';

      final deliveryAddress = DeliveryAddress(
        buildingName: 'N/A',
        street: 'N/A',
        area: 'N/A',
        city: '',
        state: '',
        pincode: '000000',
        contactNumber: userPhone,
        latitude: 0.0,
        longitude: 0.0,
      );

      debugPrint('[CheckoutScreen] Using fallback address due to profile fetch error');

      if (!mounted) return;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => OrderConfirmationModal(
          deliveryDate: _selectedDeliveryDate == 'Tomorrow'
              ? DateTime.now().add(const Duration(days: 1)).toIso8601String()
              : DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          cartItems: cartItems,
          totalAmount: totalAmount,
          deliveryAddress: deliveryAddress,
        ),
      );

      if (result != null && result['success'] == true && mounted) {
        _showSuccessDialog(result['orderNumber'], result['payment']);
      }
    }
  }

  void _showSuccessDialog(String? orderNumber, dynamic payment) {
    debugPrint('[CheckoutScreen] Displaying success dialog...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
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
                  fontWeight: AppTypography.regular,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              if (payment != null && payment.wallet != null) ...[
                const SizedBox(height: AppSizes.spacing20),
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Remaining Wallet Balance',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize12,
                          fontWeight: AppTypography.medium,
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing4),
                      Text(
                        '₹${payment.wallet.couponBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize18,
                          fontWeight: AppTypography.bold,
                          color: AppColors.primaryGreen,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Auto navigate to home after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      debugPrint('[CheckoutScreen] Success dialog timeout - clearing cart and navigating back...');

      // Clear cart (both in-memory and local storage)
      ref.read(cartProvider.notifier).clearCart();
      debugPrint('[CheckoutScreen] Cart cleared from local storage');

      // Close dialog
      Navigator.of(context).pop();
      debugPrint('[CheckoutScreen] Success dialog closed');

      // Navigate back to home (delivery screen)
      // Pop twice to go back to delivery screen (pop checkout, pop menu)
      Navigator.of(context).popUntil((route) => route.isFirst);
      debugPrint('[CheckoutScreen] Navigated back to home screen');
    });
  }
}
