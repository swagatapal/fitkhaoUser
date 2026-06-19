import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/razorpay_service.dart';
import '../../models/subscription_pricing_preview_model.dart';
import '../../providers/subscription_pricing_provider.dart';
import '../../providers/wallet_provider.dart';
import '../widgets/subscription_benefits.dart';

/// Subscription checkout.
///
/// Receives only [planId] + [cancelAnytimeSelected] — every figure shown is the
/// server-authoritative pricing preview fetched here (no data is carried from
/// the plan screen). State lives in [subscriptionPricingPreviewProvider]; the
/// screen just renders its [AsyncValue].
class SubscriptionCheckoutScreen extends ConsumerStatefulWidget {
  final String planId;
  final bool cancelAnytimeSelected;

  const SubscriptionCheckoutScreen({
    super.key,
    required this.planId,
    this.cancelAnytimeSelected = false,
  });

  @override
  ConsumerState<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends ConsumerState<SubscriptionCheckoutScreen> {
  bool _isProcessing = false;

  /// User-chosen payment method ('wallet' | 'online'), or null to use the
  /// smart default (wallet when the balance covers the total, else online).
  String? _selectedMethod;

  late final RazorpayService _razorpayService;
  String? _razorpayOrderId;

  PricingPreviewArgs get _args =>
      (planId: widget.planId, cancelAnytimeSelected: widget.cancelAnytimeSelected);

  double get _walletBalance =>
      ref.read(walletProvider.select((s) => s.wallet?.couponBalance)) ?? 0;

  /// Effective method given the wallet balance vs the payable [total].
  String _effectiveMethod(double total) =>
      _selectedMethod ?? (_walletBalance >= total ? 'wallet' : 'online');

  // ── Razorpay lifecycle ─────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(
      onSuccess: _onRazorpaySuccess,
      onFailure: _onRazorpayFailure,
      onExternalWallet: (_) {},
    );
    // Ensure the wallet balance is fresh so the wallet/online default is right.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).loadWalletBalance();
    });
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  /// The loaded preview, or null while loading / on error.
  SubscriptionPricingPreview? get _preview =>
      ref.read(subscriptionPricingPreviewProvider(_args)).valueOrNull;

  // ── Razorpay callbacks ─────────────────────────────────────────────────────

  void _onRazorpaySuccess(
    String paymentId,
    String? sdkOrderId,
    String? signature,
  ) {
    debugPrint('[SubscriptionCheckout] Razorpay success — paymentId=$paymentId');
    _verifyAndFinalise(
      paymentId: paymentId,
      sdkOrderId: sdkOrderId,
      signature: signature,
    );
  }

  void _onRazorpayFailure(int code, String message) {
    debugPrint('[SubscriptionCheckout] Razorpay failure — $code $message');
    _razorpayOrderId = null;
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showError(message);
  }

  // ── Payment flow ───────────────────────────────────────────────────────────

  void _onPayTapped() {
    if (_isProcessing) return;
    final preview = _preview;
    if (preview == null) return; // not loaded yet
    final method = _effectiveMethod(preview.pricing.totalAmount);
    _showConfirmationDialog(preview, method);
  }

  /// Wallet path: POST /api/subscription/create — creates the subscription
  /// directly from the wallet balance (no Razorpay).
  Future<void> _payWithWallet(SubscriptionPricingPreview preview) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final res = await repo.createSubscription(
        planId: widget.planId,
        cancelAnytimeSelected: widget.cancelAnytimeSelected,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (res.success) {
        await _refreshAfterPurchase();
        if (!mounted) return;
        _showSuccessDialog();
      } else {
        _showError(res.message.isNotEmpty
            ? res.message
            : 'Could not activate the subscription. Please try again.');
      }
    } catch (e) {
      debugPrint('[SubscriptionCheckout] wallet create error: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Could not activate the subscription. Please try again.');
    }
  }

  /// Refresh wallet + profile so the active subscription reflects everywhere.
  Future<void> _refreshAfterPurchase() async {
    await ref.read(walletProvider.notifier).loadWalletBalance();
  }

  void _showConfirmationDialog(
      SubscriptionPricingPreview preview, String method) {
    final viaWallet = method == 'wallet';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.help_outline,
                    size: AppSizes.icon60, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: AppSizes.spacing20),
              const Text(
                'Confirm Payment',
                style: TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing12),
              Text(
                'Pay ${_money(preview.pricing.totalAmount)} for the '
                '${preview.plan.planName} (${preview.plan.planValidity}) plan '
                '${viaWallet ? 'from your wallet' : 'online'}?',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.regular,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radius4),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.spacing8),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize16,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (viaWallet) {
                          _payWithWallet(preview);
                        } else {
                          _initiateRazorpayFlow(preview);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radius4),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.spacing8),
                      ),
                      child: const Text(
                        'Confirm',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initiateRazorpayFlow(SubscriptionPricingPreview preview) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final createResponse = await orderRepo.createRazorpaySubscriptionOrder(
        planId: widget.planId,
        cancelAnytimeSelected: widget.cancelAnytimeSelected,
      );

      if (!createResponse.success || createResponse.data == null) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showError(createResponse.message.isNotEmpty
            ? createResponse.message
            : 'Could not initiate payment. Please try again.');
        return;
      }

      final orderData = createResponse.data!;
      _razorpayOrderId = orderData.razorpayOrderId;

      // Backend is authoritative for the amount; fall back to the previewed
      // total only if the backend value is zero.
      final amountInPaise = orderData.amountInPaise > 0
          ? orderData.amountInPaise
          : (preview.pricing.totalAmount * 100).toInt();

      debugPrint(
        '[SubscriptionCheckout] Razorpay order created — '
        'orderId=${orderData.razorpayOrderId} paise=$amountInPaise',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final localStorage = ref.read(localStorageProvider).value;
      final userName = localStorage?.getUserName() ?? 'FitKhao User';
      final userEmail = localStorage?.getUserEmail() ?? '';
      final userPhone = localStorage?.getUserPhone() ?? '';

      _razorpayService.open(
        RazorpayPaymentConfig(
          amountInPaise: amountInPaise,
          orderId: orderData.razorpayOrderId,
          description: 'FitKhao ${preview.plan.planName} Subscription',
          customerName: userName,
          customerEmail: userEmail,
          customerContact: userPhone,
        ),
      );
    } catch (e) {
      debugPrint(
          '[SubscriptionCheckout] createRazorpaySubscriptionOrder error: $e');
      _razorpayOrderId = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Payment initiation failed. Please try again.');
    }
  }

  Future<void> _verifyAndFinalise({
    required String paymentId,
    required String? sdkOrderId,
    required String? signature,
  }) async {
    final razorpayOrderId = (_razorpayOrderId?.isNotEmpty == true)
        ? _razorpayOrderId!
        : (sdkOrderId ?? '');

    if (razorpayOrderId.isEmpty) {
      debugPrint('[SubscriptionCheckout] verifyPayment: razorpayOrderId empty');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Payment verification failed. Please contact support.');
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
        purpose: 'subscription',
      );

      _razorpayOrderId = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (verifyResponse.success) {
        await _refreshAfterPurchase();
        if (!mounted) return;
        _showSuccessDialog();
      } else {
        _showError(verifyResponse.message.isNotEmpty
            ? verifyResponse.message
            : 'Payment verification failed. Please contact support.');
      }
    } catch (e) {
      debugPrint('[SubscriptionCheckout] verifyRazorpayPayment error: $e');
      _razorpayOrderId = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Payment verification failed. Please try again.');
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
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
                child: const Icon(Icons.check_circle,
                    size: AppSizes.icon80, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: AppSizes.spacing24),
              const Text(
                'Subscription Successful!',
                style: TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing12),
              const Text(
                'Welcome to FitKhao Plus! Enjoy your premium benefits.',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.regular,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.spacing24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(ctx).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
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
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        title: const Text(
          'Payment Failed',
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
            onPressed: () => Navigator.of(ctx).pop(),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(subscriptionPricingPreviewProvider(_args));

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomButton(previewAsync.valueOrNull),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: previewAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryGreen),
                ),
                error: (_, __) => _ErrorView(
                  onRetry: () => ref.invalidate(
                    subscriptionPricingPreviewProvider(_args),
                  ),
                ),
                data: (preview) => _buildContent(preview),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SubscriptionPricingPreview preview) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPaddingHorizontal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSizes.spacing16),
            _buildPlanHeaderCard(preview),
            const SizedBox(height: AppSizes.spacing20),
            _buildPaymentSummary(preview),
            const SizedBox(height: AppSizes.spacing20),
            _buildPaymentMethod(preview),
            const SizedBox(height: AppSizes.spacing12),
            _buildCancellationNote(preview),
            const SizedBox(height: AppSizes.spacing20),
            _buildBenefitsSection(preview),
            const SizedBox(height: AppSizes.spacing24),
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
              child: const Icon(Icons.arrow_back,
                  color: AppColors.textWhite, size: AppSizes.icon24),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your purchase',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  'Review your plan and pay',
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

  // ─── Plan header card ───────────────────────────────────────────────────────

  Widget _buildPlanHeaderCard(SubscriptionPricingPreview preview) {
    final plan = preview.plan;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacing16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5D9E40), Color(0xFF7AB655)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.planName,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize18,
                    fontWeight: AppTypography.bold,
                    color: Colors.white,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  '${plan.planCode} · ${plan.planValidity}'
                  '${plan.features.mealCountPerDay > 0 ? ' · ${plan.features.mealCountPerDay} meals/day' : ''}',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: Colors.white.withValues(alpha: 0.9),
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
                _money(preview.pricing.planAmount),
                style: const TextStyle(
                  fontSize: AppTypography.fontSize24,
                  fontWeight: AppTypography.bold,
                  color: Colors.white,
                  fontFamily: 'Lato',
                ),
              ),
              Text(
                'base price',
                style: TextStyle(
                  fontSize: AppTypography.fontSize10,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Payment summary (all figures from the preview) ─────────────────────────

  Widget _buildPaymentSummary(SubscriptionPricingPreview preview) {
    final p = preview.pricing;
    final consultationFee = preview.plan.consultationFee;
    final showCancelFee = p.cancelAnytimeSelected && p.cancelAnytimeFee > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Summary',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        Container(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Plan amount', value: _money(p.planAmount)),

              // Consultation fee — already inside the plan amount (info only).
              if (consultationFee > 0) ...[
                const SizedBox(height: AppSizes.spacing6),
                _SummaryRow(
                  label: 'Incl. consultation fee',
                  value: _money(consultationFee),
                  muted: true,
                ),
              ],

              // Per-meal price (info only).
              if (p.pricePerMeal > 0) ...[
                const SizedBox(height: AppSizes.spacing6),
                _SummaryRow(
                  label: 'Price per meal',
                  value: _money(p.pricePerMeal),
                  muted: true,
                ),
              ],

              // Cancel-anytime add-on — only when opted in.
              if (showCancelFee) ...[
                const SizedBox(height: AppSizes.spacing12),
                _SummaryRow(
                  label: 'Cancel-anytime fee',
                  value: _money(p.cancelAnytimeFee),
                ),
              ],

              // Subtotal (shown when it differs from plan amount).
              if (p.subtotal > 0 && p.subtotal != p.planAmount) ...[
                const SizedBox(height: AppSizes.spacing12),
                _SummaryRow(label: 'Subtotal', value: _money(p.subtotal)),
              ],

              // GST.
              if (p.gstAmount > 0) ...[
                const SizedBox(height: AppSizes.spacing12),
                _SummaryRow(
                  label: 'GST (${p.gstPercent.toStringAsFixed(0)}%)',
                  value: _money(p.gstAmount),
                ),
              ],

              const SizedBox(height: AppSizes.spacing12),
              const Divider(height: 1, color: AppColors.borderColor),
              const SizedBox(height: AppSizes.spacing12),

              _SummaryRow(
                label: 'Total payable',
                value: _money(p.totalAmount),
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Payment method (wallet vs online) ──────────────────────────────────────

  Widget _buildPaymentMethod(SubscriptionPricingPreview preview) {
    final total = preview.pricing.totalAmount;
    // Watch the balance so the tiles + default react to wallet refreshes.
    final balance =
        ref.watch(walletProvider.select((s) => s.wallet?.couponBalance)) ?? 0;
    final walletOk = balance >= total;
    final method = _effectiveMethod(total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment method',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing12),
        _PaymentOptionTile(
          icon: Icons.account_balance_wallet_rounded,
          title: 'FitKhao Wallet',
          subtitle: walletOk
              ? 'Balance ${_money(balance)}'
              : 'Insufficient balance (${_money(balance)})',
          selected: method == 'wallet',
          enabled: walletOk,
          onTap: walletOk
              ? () => setState(() => _selectedMethod = 'wallet')
              : null,
        ),
        const SizedBox(height: AppSizes.spacing8),
        _PaymentOptionTile(
          icon: Icons.credit_card_rounded,
          title: 'Pay online',
          subtitle: 'UPI · Card · Net banking (Razorpay)',
          selected: method == 'online',
          enabled: true,
          onTap: () => setState(() => _selectedMethod = 'online'),
        ),
      ],
    );
  }

  // ─── Cancellation policy note ───────────────────────────────────────────────

  Widget _buildCancellationNote(SubscriptionPricingPreview preview) {
    final p = preview.pricing;
    final consultationFee = preview.plan.consultationFee;

    // Tailor the copy to whether the user opted into cancel-anytime.
    final String body;
    if (p.cancelAnytimeSelected) {
      final deductions = <String>[
        if (p.cancelAnytimeFee > 0)
          'the ${_money(p.cancelAnytimeFee)} cancel-anytime fee',
        if (consultationFee > 0)
          'the consultation fee (${_money(consultationFee)})',
        'the cost of the meals you have already consumed',
      ];
      body =
          'Cancel anytime is enabled. If you cancel, ${_joinWithAnd(deductions)} '
          'will be deducted and the remaining amount refunded to your wallet.';
    } else {
      body =
          'This plan is non-cancellable. Enable “Cancel anytime” on the plan '
          'screen if you may want to cancel later.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: AppSizes.icon18, color: Color(0xFFC66301)),
          const SizedBox(width: AppSizes.spacing10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cancellation policy',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize13,
                    fontWeight: AppTypography.bold,
                    color: Color(0xFFC66301),
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: Color(0xFF795548),
                    height: 1.4,
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

  // ─── Benefits ("what you'll get") ──────────────────────────────────────────

  Widget _buildBenefitsSection(SubscriptionPricingPreview preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.card_giftcard_rounded,
                size: AppSizes.icon20, color: AppColors.primaryGreen),
            SizedBox(width: AppSizes.spacing8),
            Text(
              "What you'll get",
              style: TextStyle(
                fontSize: AppTypography.fontSize18,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacing12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.spacing16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border:
                Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.18)),
          ),
          child: SubscriptionBenefitsList(plan: preview.plan),
        ),
      ],
    );
  }

  Widget _buildBottomButton(SubscriptionPricingPreview? preview) {
    final canPay = preview != null && !_isProcessing;
    final String label;
    if (preview == null) {
      label = 'Loading…';
    } else {
      final viaWallet =
          _effectiveMethod(preview.pricing.totalAmount) == 'wallet';
      label = viaWallet
          ? 'Pay ${_money(preview.pricing.totalAmount)} via Wallet'
          : 'Pay ${_money(preview.pricing.totalAmount)}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing12,
          AppSizes.screenPaddingHorizontal,
          AppSizes.spacing12,
        ),
        child: SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: ElevatedButton(
            onPressed: canPay ? _onPayTapped : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.primaryGreen.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              elevation: 0,
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize18,
                      fontWeight: AppTypography.bold,
                      fontFamily: 'Lato',
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  static String _money(double amount) =>
      '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';

  /// Joins a list into readable prose: "a, b and c".
  static String _joinWithAnd(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }
}

// ─── Error view ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 44, color: AppColors.errorColor),
            const SizedBox(height: AppSizes.spacing12),
            const Text(
              'Could not load pricing. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
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
      ),
    );
  }
}

// ─── Payment option tile ─────────────────────────────────────────────────────

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primaryGreen;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSizes.spacing12),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border: Border.all(
              color: selected
                  ? accent
                  : AppColors.borderColor.withValues(alpha: 0.6),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: AppSizes.icon24,
                  color: selected ? accent : AppColors.textSecondary),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: AppSizes.icon20,
                color: selected ? accent : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool isBold;

  /// Renders as a smaller, secondary "included" line — not a charged total.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final fontSize = muted
        ? AppTypography.fontSize12
        : (isBold ? AppTypography.fontSize16 : AppTypography.fontSize14);
    final color = muted
        ? AppColors.textSecondary
        : (isBold ? AppColors.primaryGreen : AppColors.textPrimary);
    final weight = isBold ? AppTypography.bold : AppTypography.regular;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: muted ? AppTypography.fontSize12 : AppTypography.fontSize14,
            fontWeight: weight,
            color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            color: color,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }
}
