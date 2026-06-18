import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/razorpay_service.dart';
import '../../../policy/providers/app_constants_provider.dart';
import '../../models/subscription_plan_model.dart';
import '../widgets/subscription_benefits.dart';

class SubscriptionCheckoutScreen extends ConsumerStatefulWidget {
  /// The full plan selected on the previous screen — carries the pricing
  /// breakdown (price, consultation fee, other charges, GST) and the feature
  /// set, so checkout never re-fetches and the summary is always plan-specific.
  final SubscriptionPlan plan;

  const SubscriptionCheckoutScreen({super.key, required this.plan});

  @override
  ConsumerState<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState
    extends ConsumerState<SubscriptionCheckoutScreen> {
  bool _isProcessing = false;

  late final RazorpayService _razorpayService;
  String? _razorpayOrderId;

  SubscriptionPlan get _plan => widget.plan;

  /// Any-time cancellation fee (₹) from /api/app/constants. Refreshed in
  /// [build] from the cached [appConstantsProvider]; held in a field so the
  /// pricing getters stay usable from dialogs / the pay button too.
  double _cancellationFee = 0;

  // ─── Pricing breakdown ──────────────────────────────────────────────────────
  // The backend stays authoritative for the charged amount; this breakdown is
  // for transparent display and the local fallback total.
  //
  //   • Plan amount   → plan.price (the actual amount; consultation fee is
  //                     already baked into it, so it's never added separately).
  //   • GST           → computed on the actual amount only.
  //   • Total payable → plan amount + GST.
  // The cancellation fee is NOT charged now — it only applies if the user later
  // cancels, so it is shown purely as a policy note, never in the total.

  double get _planAmount => _plan.price;

  /// Consultation fee — already included inside [_planAmount]; surfaced for
  /// transparency and reused in the cancellation policy note.
  double get _consultationFee => _plan.consultationFee;

  double get _gstAmount => _planAmount * _plan.gstPercentage / 100;

  /// Flat any-time cancellation fee from app constants. Informational only.
  double get _cancellationCharge => _cancellationFee;

  double get _totalAmount => _planAmount + _gstAmount;

  String get _formattedTotal => _formatAmount(_totalAmount);

  // ── Razorpay lifecycle ─────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(
      onSuccess: _onRazorpaySuccess,
      onFailure: _onRazorpayFailure,
      onExternalWallet: (_) {},
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  // ── Razorpay callbacks ─────────────────────────────────────────────────────

  void _onRazorpaySuccess(
    String paymentId,
    String? sdkOrderId,
    String? signature,
  ) {
    debugPrint(
        '[SubscriptionCheckout] Razorpay success — paymentId=$paymentId');
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
    _showConfirmationDialog();
  }

  void _showConfirmationDialog() {
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
                child: const Icon(
                  Icons.help_outline,
                  size: AppSizes.icon60,
                  color: AppColors.primaryGreen,
                ),
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
                'Proceed with payment of $_formattedTotal for the '
                '${_plan.planName} (${_plan.planValidity}) plan?',
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
                          borderRadius:
                              BorderRadius.circular(AppSizes.radius4),
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
                        _initiateRazorpayFlow();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radius4),
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

  Future<void> _initiateRazorpayFlow() async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final createResponse = await orderRepo.createRazorpaySubscriptionOrder(
        planCode: _plan.planCode,
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

      // Backend is authoritative for the amount; fall back to the local total
      // only if the backend value is zero.
      final amountInPaise = orderData.amountInPaise > 0
          ? orderData.amountInPaise
          : (_totalAmount * 100).toInt();

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
          description: 'FitKhao ${_plan.planName} Subscription',
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
      debugPrint(
          '[SubscriptionCheckout] verifyPayment: razorpayOrderId empty');
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
        planCode: _plan.planCode,
      );

      _razorpayOrderId = null;
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (verifyResponse.success) {
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
                child: const Icon(
                  Icons.check_circle,
                  size: AppSizes.icon80,
                  color: AppColors.primaryGreen,
                ),
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
    // Cancellation fee comes from the globally-cached app constants; reading it
    // here keeps the summary + pay button reactive once the value loads.
    _cancellationFee = ref
            .watch(appConstantsProvider)
            .valueOrNull
            ?.subscriptionCancellationFee ??
        0;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomButton(),
      body: SafeArea(
        bottom: false,
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
                      _buildPlanHeaderCard(),
                      const SizedBox(height: AppSizes.spacing20),
                      _buildPaymentSummary(),
                      if (_plan.rules.canCancel) ...[
                        const SizedBox(height: AppSizes.spacing12),
                        _buildCancellationNote(),
                      ],
                      const SizedBox(height: AppSizes.spacing20),
                      _buildBenefitsSection(),
                      const SizedBox(height: AppSizes.spacing24),
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

  // ─── Plan header card (name + duration + headline price) ────────────────────

  Widget _buildPlanHeaderCard() {
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
                  _plan.planName,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize18,
                    fontWeight: AppTypography.bold,
                    color: Colors.white,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(height: AppSizes.spacing4),
                Text(
                  '${_plan.planCode} · ${_plan.planValidity}',
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
                _plan.formattedPrice,
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

  // ─── Payment summary ────────────────────────────────────────────────────────

  Widget _buildPaymentSummary() {
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
              // Actual plan amount (consultation fee already included).
              _SummaryRow(
                label: 'Plan amount',
                value: _formatAmount(_planAmount),
              ),

              // Consultation fee — already inside the plan amount, shown for
              // transparency, so it's a muted "included" note (not added again).
              if (_consultationFee > 0) ...[
                const SizedBox(height: AppSizes.spacing6),
                _SummaryRow(
                  label: 'Incl. consultation fee',
                  value: _formatAmount(_consultationFee),
                  muted: true,
                ),
              ],

              // GST on the actual amount — shown only when the plan has a rate.
              if (_plan.gstPercentage > 0) ...[
                const SizedBox(height: AppSizes.spacing12),
                _SummaryRow(
                  label: 'GST (${_plan.gstPercentage.toStringAsFixed(0)}%)',
                  value: _formatAmount(_gstAmount),
                ),
              ],

              const SizedBox(height: AppSizes.spacing12),
              const Divider(height: 1, color: AppColors.borderColor),
              const SizedBox(height: AppSizes.spacing12),

              // Total payable (plan + GST — cancellation fee is not charged now)
              _SummaryRow(
                label: 'Total payable',
                value: _formatAmount(_totalAmount),
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Cancellation policy note ───────────────────────────────────────────────

  Widget _buildCancellationNote() {
    // Build the deduction list dynamically so zero-value parts are dropped.
    final deductions = <String>[
      if (_cancellationCharge > 0)
        'a ${_formatAmount(_cancellationCharge)} cancellation fee',
      if (_consultationFee > 0)
        'the consultation fee (${_formatAmount(_consultationFee)})',
      'the cost of the meals you have already consumed',
    ];

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
                  'If you cancel this subscription, ${_joinWithAnd(deductions)} '
                  'will be deducted, and the remaining amount will be refunded '
                  'to your wallet.',
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

  Widget _buildBenefitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.card_giftcard_rounded,
                size: AppSizes.icon20, color: AppColors.primaryGreen),
            const SizedBox(width: AppSizes.spacing8),
            const Text(
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
          child: SubscriptionBenefitsList(plan: _plan),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
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
            onPressed: _isProcessing ? null : _onPayTapped,
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
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Pay $_formattedTotal',
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

  static String _formatAmount(double amount) =>
      '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';

  /// Joins a list into readable prose: "a, b and c".
  static String _joinWithAnd(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
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
    final labelColor =
        muted ? AppColors.textSecondary : AppColors.textPrimary;
    final valueColor = muted
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
            color: labelColor,
            fontFamily: 'Lato',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            color: valueColor,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }
}
