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

  // Mock coupon balance
  final double _couponBalance = 2399.0;

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);

    // Calculate GST (23% of total)
    final gst = totalPrice * 0.23;
    final subTotal = totalPrice + gst;
    final deducted = subTotal > _couponBalance ? _couponBalance : subTotal;
    final remainingBalance = _couponBalance - deducted;

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
                      const SizedBox(height: AppSizes.spacing20),
                      _buildFitKhaoLogo(),
                      const SizedBox(height: AppSizes.spacing20),
                      _buildCartItems(cartItems),
                      const SizedBox(height: AppSizes.spacing24),
                      _buildDeliveryDateSection(),
                      const SizedBox(height: AppSizes.spacing24),
                      _buildPaymentSummary(
                        totalPrice,
                        gst,
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

  Widget _buildFitKhaoLogo() {
    return LogoWidget();
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
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDeliveryDate = date;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: AppColors.primaryGreen,
            width: AppSizes.borderMedium,
          ),
        ),
        child: Center(
          child: Text(
            date,
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              fontWeight: AppTypography.semiBold,
              color: isSelected ? Colors.white : AppColors.primaryGreen,
              fontFamily: 'Lato',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummary(
    double totalPrice,
    double gst,
    double subTotal,
    double deducted,
    double remainingBalance,
      )
  {
    final wallet = ref.watch(walletProvider).wallet;
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

        // Item total and GST
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
                AppStrings.gst,
                '₹${gst.toStringAsFixed(2)}',
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

    // Calculate total with GST
    final gst = totalPrice * 0.23;
    final grandTotal = totalPrice + gst;

    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        onPressed: cartItems.isEmpty ? null : () {
          _showOrderConfirmationModal(cartItems, grandTotal);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
        ),
        child: const Text(
          AppStrings.confirmOrder,
          style: TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: AppTypography.semiBold,
            color: Colors.white,
            fontFamily: 'Lato',
          ),
        ),
      ),
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
        _showSuccessDialog(result['order'], result['payment']);
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
        _showSuccessDialog(result['order'], result['payment']);
      }
    }
  }

  void _showSuccessDialog(dynamic order, dynamic payment) {
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
              if (order != null)
                Text(
                  'Order #${order.orderNumber}',
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
