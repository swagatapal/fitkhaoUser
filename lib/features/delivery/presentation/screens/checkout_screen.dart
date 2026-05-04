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
import '../widgets/order_confirmation_modal.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  // 'wallet' | 'gateway'
  String _selectedPaymentMethod = 'wallet';
  final TextEditingController _instructionsController = TextEditingController();

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

    const gst = 0.05; // 5%
    const platformCharge = 7.0;
    final itemTotal = totalPrice;
    final gstAmount = totalPrice * gst;
    final subTotal = itemTotal + gstAmount + platformCharge;
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
          // Food image
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
          // Item details
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
          // Price + quantity controls
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
                          ref.read(cartProvider.notifier).removeItem(
                            cartItem.menuItem.id,
                          );
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
                      onTap: () => ref.read(cartProvider.notifier).updateQuantity(
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
        child: Icon(icon, size: AppSizes.icon16, color: AppColors.primaryGreen),
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
                  : 'Insufficient balance — ₹${couponBalance.toStringAsFixed(2)} available, ₹${subTotal.toStringAsFixed(2)} required',
              isSelected: _selectedPaymentMethod == 'wallet' && isWalletSufficient,
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
              color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
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
              _buildSummaryRow('GST (5%)', '₹${gstAmount.toStringAsFixed(2)}'),
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
              borderSide:
                  const BorderSide(color: AppColors.borderColor),
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
    final canPlace = cartItems.isNotEmpty &&
        (_selectedPaymentMethod == 'gateway' ||
            (_selectedPaymentMethod == 'wallet' && isWalletSufficient));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canPlace &&
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
                Icon(Icons.info_outline,
                    color: AppColors.errorColor, size: AppSizes.icon20),
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
            child: walletState.isLoading
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

  Future<void> _placeOrder(List<CartItem> cartItems, double totalAmount) async {
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
      );

      if (!mounted) return;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OrderConfirmationModal(
          deliveryDate: DateTime.now().toIso8601String(),
          cartItems: cartItems,
          totalAmount: totalAmount,
          deliveryAddress: deliveryAddress,
        ),
      );

      if (result != null && result['success'] == true && mounted) {
        _showSuccessDialog(result['orderNumber'], result['payment']);
      }
    } catch (e) {
      debugPrint('[CheckoutScreen] Error placing order: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to fetch delivery address. Please update your profile.',
          ),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSuccessDialog(String? orderNumber, dynamic payment) {
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

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      ref.read(cartProvider.notifier).clearCart();
      Navigator.of(context).pop();
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }
}
