import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:math';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../providers/wallet_provider.dart';
import '../../../../core/providers/providers.dart';

class RechargeTopupModal extends ConsumerStatefulWidget {
  const RechargeTopupModal({super.key});

  @override
  ConsumerState<RechargeTopupModal> createState() => _RechargeTopupModalState();
}

class _RechargeTopupModalState extends ConsumerState<RechargeTopupModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedPaymentMethod = 'UPI';
  bool _isProcessing = false;

  late Razorpay _razorpay;


  final List<String> _paymentMethods = [
    'UPI',
    'Net Banking',
    'Debit Card',
    'Credit Card',
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _razorpay = Razorpay();

    // Attach event listeners
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  // ✅ Payment Success
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('Payment Success: ${response.paymentId}');
    // TODO: Verify payment on your backend using response.paymentId
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Successful! ID: ${response.paymentId}')),
    );
  }
// ❌ Payment Failed
  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment Error: ${response.code} | ${response.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Failed: ${response.message}')),
    );
  }

  // 👛 External Wallet (PayTM, PhonePe, etc.)
  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
  }

  // 🚀 Open Razorpay Checkout
  void _openCheckout() {
    var options = {
      'key': 'rzp_test_SfHVw0QfOq1N0X', // 🔑 Your test key here
      'amount': 1000,                   // Amount in PAISE (50000 = ₹500)
      'name': 'FitKhao',
      'description': 'Payment for Order #1234',
      'currency': 'INR',
      'prefill': {
        'contact': '9876543210',
        'email': 'user@example.com',
      },
      'theme': {
        'color': '#00A86B',             // Checkout UI color
      },
      'retry': {
        'enabled': true,
        'max_count': 3,
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error opening Razorpay: $e');
    }
  }

  String _generateTransactionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(999999);
    return 'txn_${timestamp}_$randomNum';
  }

  Future<void> _showConfirmationDialog() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = int.parse(_amountController.text);
    final description = _descriptionController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        title: const Text(
          'Confirm Top-up',
          style: TextStyle(
            fontSize: AppTypography.fontSize20,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfirmationRow('Amount', '₹$amount'),
            const SizedBox(height: AppSizes.spacing12),
            _buildConfirmationRow('Payment Method', _selectedPaymentMethod),
            if (description.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing12),
              _buildConfirmationRow('Description', description),
            ],
            const SizedBox(height: AppSizes.spacing16),
            const Text(
              'Are you sure you want to proceed with this top-up?',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.regular,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.medium,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
          ),
          ElevatedButton(
            //onPressed: () => Navigator.of(context).pop(true),
            onPressed: () => _openCheckout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius4),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.bold,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _processTopup();
    }
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: AppTypography.medium,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(width: AppSizes.spacing8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: AppTypography.fontSize14,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Future<void> _processTopup() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final amount = int.parse(_amountController.text);
      final description = _descriptionController.text.trim();
      final transactionId = _generateTransactionId();

      final walletRepo = ref.read(walletRepositoryProvider);
      final response = await walletRepo.topupWallet(
        amount: amount,
        paymentMethod: _selectedPaymentMethod,
        transactionId: transactionId,
        description: description.isNotEmpty ? description : null,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (response.success) {
          // Refresh wallet balance
          final walletNotifier = ref.read(walletProvider.notifier);
          await walletNotifier.loadWalletBalance();

          // Close modal
          if (mounted) {
            Navigator.of(context).pop();

            // Show success dialog
            _showSuccessDialog(response);
          }
        } else {
          _showErrorDialog(response.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showErrorDialog('Failed to process top-up. Please try again.');
      }
    }
  }

  void _showSuccessDialog(dynamic response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.primaryGreen,
                size: AppSizes.icon60,
              ),
            ),
            const SizedBox(height: AppSizes.spacing20),
            const Text(
              'Top-up Successful!',
              style: TextStyle(
                fontSize: AppTypography.fontSize20,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              response.message ?? 'Your wallet has been topped up successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.regular,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            if (response.data?.wallet != null) ...[
              const SizedBox(height: AppSizes.spacing20),
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Updated Balance',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: AppTypography.medium,
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing4),
                    Text(
                      '₹${response.data.wallet.couponBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize24,
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
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
              ),
              child: const Text(
                'Done',
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
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        title: const Text(
          'Top-up Failed',
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
                        Icons.account_balance_wallet,
                        color: AppColors.primaryGreen,
                        size: AppSizes.icon24,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing12),
                    const Expanded(
                      child: Text(
                        'Recharge Wallet',
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
                // Amount field
                const Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: 'Enter amount (min ₹1000)',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing16,
                      vertical: AppSizes.spacing12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final amount = int.tryParse(value);
                    if (amount == null) {
                      return 'Please enter a valid amount';
                    }
                    if (amount < 1000) {
                      return 'Minimum amount is ₹1000';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spacing20),
                // Payment method
                const Text(
                  'Payment Method',
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
                    //initialValue: _selectedPaymentMethod,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacing16,
                        vertical: AppSizes.spacing12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                        borderSide: const BorderSide(color: AppColors.textWhite),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                        borderSide: const BorderSide(color: AppColors.textWhite, width: 2),
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: _paymentMethods.map((method) {
                      return DropdownMenuItem(
                        value: method,
                        child: Row(
                          children: [
                            Icon(
                              _getPaymentIcon(method),
                              size: AppSizes.icon20,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: AppSizes.spacing12),
                            Text(
                              method,
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
                          _selectedPaymentMethod = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppSizes.spacing20),
                // Description field (optional)
                const Text(
                  'Description (Optional)',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add a note (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing16,
                      vertical: AppSizes.spacing12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing24),
                // Pay button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _showConfirmationDialog,
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
                            'Pay Now',
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

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'UPI':
        return Icons.qr_code_2;
      case 'Net Banking':
        return Icons.account_balance;
      case 'Debit Card':
      case 'Credit Card':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }
}
