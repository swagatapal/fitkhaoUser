import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../providers/wallet_provider.dart';
import '../../models/order_placement_model.dart';
import '../../models/cart_item.dart';

class OrderConfirmationModal extends ConsumerStatefulWidget {
  final String deliveryDate;
  final List<CartItem> cartItems;
  final double totalAmount;
  final DeliveryAddress deliveryAddress;

  const OrderConfirmationModal({
    super.key,
    required this.deliveryDate,
    required this.cartItems,
    required this.totalAmount,
    required this.deliveryAddress,
  });

  @override
  ConsumerState<OrderConfirmationModal> createState() =>
      _OrderConfirmationModalState();
}

class _OrderConfirmationModalState
    extends ConsumerState<OrderConfirmationModal> {
  final _formKey = GlobalKey<FormState>();
  final _specialInstructionsController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();
  String _selectedDeliverySlot = 'morning';
  bool _isProcessing = false;

  final Map<String, String> _deliverySlots = {
    'morning': 'Morning (8-9 AM)',
    'afternoon': 'Afternoon (12-1 PM)',
    'evening': 'Evening (8-9 PM)',
  };

  @override
  void dispose() {
    _specialInstructionsController.dispose();
    _deliveryInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _confirmOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final orderRepo = ref.read(orderRepositoryProvider);

      // Prepare order items
      final orderItems = widget.cartItems.map((cartItem) {
        return OrderItem(
          foodItemId: cartItem.menuItem.id,
          quantity: cartItem.quantity,
          specialInstructions:
              _specialInstructionsController.text.trim().isNotEmpty
              ? _specialInstructionsController.text.trim()
              : null,
        );
      }).toList();

      // Update delivery address with delivery instructions
      final deliveryAddress = DeliveryAddress(
        buildingName: widget.deliveryAddress.buildingName,
        street: widget.deliveryAddress.street,
        area: widget.deliveryAddress.area,
        city: widget.deliveryAddress.city,
        state: widget.deliveryAddress.state,
        pincode: widget.deliveryAddress.pincode,
        contactNumber: widget.deliveryAddress.contactNumber,
        latitude: widget.deliveryAddress.latitude,
        longitude: widget.deliveryAddress.longitude,
        deliveryInstructions:
            _deliveryInstructionsController.text.trim().isNotEmpty
            ? _deliveryInstructionsController.text.trim()
            : null,
      );

      // Determine foodType based on cart items
      // Priority: non-veg > eggetarian > vegan > veg
      String foodType = 'veg';
      for (final cartItem in widget.cartItems) {
        final itemType = cartItem.menuItem.menuType.toLowerCase();
        if (itemType == 'nonveg' || itemType == 'non-veg') {
          foodType = 'non-veg';
          break; // Non-veg has highest priority
        } else if (itemType == 'eggetarian' && foodType != 'non-veg') {
          foodType = 'eggetarian';
        } else if (itemType == 'vegan' && foodType == 'veg') {
          foodType = 'vegan';
        }
      }

      // Step 1: Place order
      final orderResponse = await orderRepo.placeOrder(
        kitchenId: '69275ba5c538faaf25e2acd1',
        // TODO: Get from menu/kitchen selection
        deliveryDate: (widget.deliveryDate).substring(0, 10),
        deliverySlot: _selectedDeliverySlot,
        items: orderItems,
        deliveryAddress: deliveryAddress,
        paymentMethod: 'wallet',
        orderType: 'single-meal',
        foodType: foodType,
        specialInstructions:
            _specialInstructionsController.text.trim().isNotEmpty
            ? _specialInstructionsController.text.trim()
            : null,
      );

      if (mounted && orderResponse.success && orderResponse.data != null) {
        // Refresh wallet balance
        final walletNotifier = ref.read(walletProvider.notifier);
        await walletNotifier.loadWalletBalance();
        // Close modal and return success data to checkout screen
        if (mounted) {
          debugPrint(
            '[OrderConfirmationModal] Returning success data to checkout screen...',
          );
          Navigator.of(context).pop({
            'success': true,
            'orderNumber': orderResponse.data!.orderNumber,
            'total': orderResponse.data!.total,
            'paymentStatus': orderResponse.data!.paymentStatus,
            // 'payment': paymentResponse.data,
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          _showErrorDialog(orderResponse.message);
        }
      }

      // if (mounted && orderResponse.success && orderResponse.data != null) {
      //   final orderNumber = orderResponse.data!.orderNumber;
      //
      //   // Step 2: Process wallet payment with amount from payment summary
      //   final paymentResponse = await orderRepo.processWalletPayment(
      //     orderId: orderNumber,
      //     amount: widget.totalAmount,
      //     paymentMethod: 'wallet',
      //   );
      //
      //   if (mounted) {
      //     setState(() {
      //       _isProcessing = false;
      //     });
      //
      //     if (paymentResponse.success) {
      //       debugPrint('[OrderConfirmationModal] Payment successful! Order Number: ${orderResponse.data!.orderNumber}');
      //
      //       // Refresh wallet balance
      //       final walletNotifier = ref.read(walletProvider.notifier);
      //       await walletNotifier.loadWalletBalance();
      //       debugPrint('[OrderConfirmationModal] Wallet balance refreshed');
      //
      //       // Close modal and return success data to checkout screen
      //       if (mounted) {
      //         debugPrint('[OrderConfirmationModal] Returning success data to checkout screen...');
      //         Navigator.of(context).pop({
      //           'success': true,
      //           'orderNumber': orderResponse.data!.orderNumber,
      //           'total': orderResponse.data!.total,
      //           'paymentStatus': orderResponse.data!.paymentStatus,
      //           'payment': paymentResponse.data,
      //         });
      //       }
      //     } else {
      //       _showErrorDialog(paymentResponse.message);
      //     }
      //   }
      // } else {
      //   if (mounted) {
      //     setState(() {
      //       _isProcessing = false;
      //     });
      //     _showErrorDialog(orderResponse.message);
      //   }
      // }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showErrorDialog('Failed to place order. Please try again.');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        title: const Text(
          'Order Failed',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: AppTypography.regular,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.medium,
                color: AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.spacing12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: AppColors.primaryGreen,
                        size: AppSizes.icon24,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    const Expanded(
                      child: Text(
                        'Confirm Order',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize20,
                          fontWeight: AppTypography.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing24),
                // Delivery Slot
                const Text(
                  'Delivery Slot',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderColor),
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDeliverySlot,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacing16,
                        vertical: AppSizes.spacing12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                        borderSide: const BorderSide(
                          color: AppColors.borderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                        borderSide: const BorderSide(
                          color: AppColors.textWhite,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                        borderSide: const BorderSide(
                          color: AppColors.textWhite,
                          width: 2,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: _deliverySlots.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(
                              _getSlotIcon(entry.key),
                              size: AppSizes.icon20,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: AppSizes.spacing12),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: AppTypography.fontSize14,
                                fontWeight: AppTypography.medium,
                                fontFamily: 'Lato',
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDeliverySlot = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),
                // Special Instructions for Cook
                const Text(
                  'Special Instructions for Cook (Optional)',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                TextFormField(
                  controller: _specialInstructionsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g., No onions, extra spicy, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing16,
                      vertical: AppSizes.spacing12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),
                // Delivery Instructions
                const Text(
                  'Delivery Instructions (Optional)',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                TextFormField(
                  controller: _deliveryInstructionsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g., Ring the bell twice, leave at door, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing16,
                      vertical: AppSizes.spacing12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing24),
                // Order Summary
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize16,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      Text(
                        '₹${widget.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize20,
                          fontWeight: AppTypography.bold,
                          color: AppColors.primaryGreen,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacing24),
                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                      ),
                      elevation: 2,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Confirm Order',
                            style: TextStyle(
                              fontSize: AppTypography.fontSize16,
                              fontWeight: AppTypography.bold,
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

  IconData _getSlotIcon(String slot) {
    switch (slot) {
      case 'morning':
        return Icons.wb_sunny;
      case 'afternoon':
        return Icons.wb_cloudy;
      case 'evening':
        return Icons.nights_stay;
      default:
        return Icons.access_time;
    }
  }
}
