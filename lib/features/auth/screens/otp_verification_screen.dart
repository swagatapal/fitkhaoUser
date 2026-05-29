import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_auth/smart_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../shared/widgets/logo_widget.dart';
import '../../../shared/widgets/primary_button.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  bool _isConfirming = false;

  // SMS User Consent API — works with any SMS format, no app-hash in SMS needed,
  // no READ_SMS permission required.
  final SmartAuth _smartAuth = SmartAuth();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initOtpFields();
    _startSmsListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNodes.first.requestFocus();
      _showReceivedOtpSnackBar();
    });
  }

  void _initOtpFields() {
    _otpControllers = List.generate(
      AppSizes.maxLengthOTP,
      (_) => TextEditingController(),
    );

    // FocusNode with built-in backspace navigation: pressing backspace on an
    // empty box moves focus to the previous one.
    _otpFocusNodes = List.generate(AppSizes.maxLengthOTP, (index) {
      return FocusNode(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _otpControllers[index].text.isEmpty &&
              index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
      );
    });
  }

  // ── SMS User Consent listener ─────────────────────────────────────────────

  /// Starts the Android SMS User Consent listener.
  ///
  /// How it works:
  ///   1. We call [SmartAuth.getSmsCode] with [useUserConsentApi] = true.
  ///   2. When an SMS arrives Android shows a system bottom-sheet:
  ///      "Allow `AppName` to read this message? `SMS preview`"
  ///   3. The user taps "Allow" — Android hands the SMS text to us.
  ///   4. [smart_auth] applies the regex to extract just the OTP digits.
  ///   5. [_fillOtpBoxes] distributes the digits into the individual boxes.
  ///
  /// Why this works without the app-hash in the SMS:
  ///   SMS Retriever API needs the hash; SMS User Consent API does NOT.
  ///   The trade-off is one extra user tap on the consent sheet.
  Future<void> _startSmsListener() async {
    try {
      // Print the app signature in debug builds — keep this so the backend
      // team can optionally add it later to switch to the zero-tap Retriever.
      assert(() {
        _smartAuth.getAppSignature().then(
          (hash) => debugPrint('[OtpScreen] App hash (for SMS Retriever): $hash'),
        );
        return true;
      }());

      final result = await _smartAuth.getSmsCode(
        // Match exactly the number of OTP digits the app expects.
        matcher: '\\d{${AppSizes.maxLengthOTP}}',
        // ← SMS User Consent API (no app-hash needed in the SMS).
        useUserConsentApi: true,
      );

      if (!mounted) return;

      debugPrint('[OtpScreen] SMS result — succeed:${result.succeed} '
          'codeFound:${result.codeFound} code:${result.code}');

      if (result.codeFound && result.code != null && result.code!.isNotEmpty) {
        _fillOtpBoxes(result.code!);
      }
    } catch (e) {
      // Non-fatal: user can always type the OTP manually.
      debugPrint('[OtpScreen] SMS listener error: $e');
    }
  }

  @override
  void dispose() {
    _smartAuth.removeSmsListener();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  // ── OTP population ─────────────────────────────────────────────────────────

  /// Fills individual OTP boxes from [raw].
  ///
  /// Accepts either a bare digit string ("123456") or a full SMS body —
  /// the regex `\D` strip ensures only digits are distributed.
  ///
  /// Entry points:
  ///   1. Android SMS User Consent — [result.code] from [_startSmsListener].
  ///   2. iOS system OTP suggestion — full code delivered in one [onChanged].
  ///   3. Manual clipboard paste into any box.
  void _fillOtpBoxes(String raw) {
    // Use exact-length regex first so a stray number in the SMS body
    // (e.g. a phone number) can never shadow the real OTP.
    final match = RegExp('\\d{${AppSizes.maxLengthOTP}}').firstMatch(raw);
    final digits = match?.group(0) ?? raw.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) return;

    final length = digits.length.clamp(0, AppSizes.maxLengthOTP);

    for (int i = 0; i < AppSizes.maxLengthOTP; i++) {
      final char = i < length ? digits[i] : '';
      // TextEditingValue is required here — setting .text directly silently
      // fails when the TextField is currently focused.
      _otpControllers[i].value = TextEditingValue(
        text: char,
        selection: TextSelection.collapsed(offset: char.length),
      );
    }

    final otp = digits.substring(0, length);
    ref.read(authProvider.notifier).updateOtp(otp);

    // Unfocus when all boxes are filled so the user sees the complete OTP
    // and can tap Confirm; focus the next empty box for partial fills.
    if (length >= AppSizes.maxLengthOTP) {
      _otpFocusNodes.last.unfocus();
    } else {
      _otpFocusNodes[length].requestFocus();
    }

    setState(() {});
  }

  // ── Field change handler ───────────────────────────────────────────────────

  void _handleOtpChange(int index, String value) {
    // iOS system OTP suggestion or paste: whole OTP lands in one onChange.
    if (value.length > 1) {
      _fillOtpBoxes(value);
      return;
    }

    if (value.isNotEmpty && index < AppSizes.maxLengthOTP - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isNotEmpty && index == AppSizes.maxLengthOTP - 1) {
      _otpFocusNodes[index].unfocus();
    }

    final otp = _otpControllers.map((c) => c.text).join();
    ref.read(authProvider.notifier).updateOtp(otp);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handleConfirm() async {
    if (_isConfirming) return;
    _isConfirming = true;

    try {
      final authNotifier = ref.read(authProvider.notifier);
      final response = await authNotifier.verifyOtp();

      if (response != null && mounted) {
        authNotifier.registerDevice().then((ok) {
          debugPrint(
            '[OtpScreen] Device registration ${ok ? 'succeeded' : 'failed'}',
          );
        }).catchError((e) {
          debugPrint('[OtpScreen] Device registration error: $e');
        });

        final hasProfile =
            response.user?.name != null && response.user!.name!.isNotEmpty;

        if (hasProfile) {
          context.go(RouteNames.home);
        } else {
          context.go(RouteNames.nameInput);
        }
      }
    } finally {
      if (mounted) _isConfirming = false;
    }
  }

  Future<void> _handleResend() async {
    for (final c in _otpControllers) { c.clear(); }
    ref.read(authProvider.notifier).updateOtp('');
    _isConfirming = false;
    setState(() {});

    final success = await ref.read(authProvider.notifier).resendOtp();
    if (!mounted) return;

    if (success) {
      _otpFocusNodes.first.requestFocus();
      _showReceivedOtpSnackBar();
      // Re-arm the SMS listener for the newly sent OTP.
      _startSmsListener();
    }
  }

  void _showReceivedOtpSnackBar() {
    final msg = ref.read(authProvider).receivedOtpMessage;
    if (msg == null || msg.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: AppColors.errorColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
      }
    });

    final horizontalPadding = context.horizontalPadding;
    final verticalPadding   = context.verticalPadding;
    final spacing12  = context.responsiveSpacing(12.0);
    final spacing16  = context.responsiveSpacing(16.0);
    final spacing32  = context.responsiveSpacing(32.0);
    final spacing40  = context.responsiveSpacing(40.0);
    final spacing48  = context.responsiveSpacing(48.0);
    final radiusSmall = context.responsiveSpacing(4.0);
    final otpBoxSize  = context.isSmallMobile ? 40.0 : 50.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing40),

              // ── Logo ──────────────────────────────────────────────────────
              const Center(child: LogoWidget()),
              SizedBox(height: spacing48),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                AppStrings.confirmPhoneNumber,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: context.responsiveFontSize(22.0),
                  fontFamily: 'Lato',
                ),
              ),
              SizedBox(height: spacing16),

              // ── Subtitle ──────────────────────────────────────────────────
              RichText(
                text: TextSpan(
                  text: AppStrings.confirmationCodeSent,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF2B292A),
                    fontWeight: FontWeight.w400,
                    fontSize: context.responsiveFontSize(16.0),
                    fontFamily: 'Lato',
                  ),
                  children: [
                    TextSpan(
                      text: '\n${authState.countryCode} ${authState.phoneNumber}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: context.responsiveFontSize(16.0),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing40),

              // ── Code label ────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    AppStrings.codeLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: context.responsiveFontSize(14.0),
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing4),
                  Text(
                    '*',
                    style: TextStyle(
                      color: AppColors.errorColor,
                      fontSize: context.responsiveFontSize(AppTypography.fontSize16),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing12),

              // ── OTP boxes ─────────────────────────────────────────────────
              // AutofillGroup + autofillHints = [oneTimeCode] enables the iOS
              // native OTP suggestion banner above the keyboard.
              // Android autofill is handled by the SmartAuth listener above.
              AutofillGroup(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(AppSizes.maxLengthOTP, (index) {
                    return SizedBox(
                      width: otpBoxSize,
                      height: otpBoxSize,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: AppSizes.maxLengthOTPDigit,
                        enabled: !authState.isLoading,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: context.responsiveFontSize(16.0),
                              fontFamily: 'Lato',
                            ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: context.responsiveSpacing(10.0),
                            vertical: context.responsiveSpacing(8.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radiusSmall),
                            borderSide: const BorderSide(
                              color: AppColors.borderColor,
                              width: AppSizes.borderMedium,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radiusSmall),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: AppSizes.borderMedium,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          _handleOtpChange(index, value);
                          setState(() {});
                        },
                        onTap: () => setState(() {}),
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(height: spacing32),

              // ── Confirm button ─────────────────────────────────────────────
              PrimaryButton(
                text: AppStrings.confirm,
                textColor: Colors.white,
                onPressed: authState.otp.length == AppSizes.maxLengthOTP &&
                        !authState.isLoading &&
                        !_isConfirming
                    ? _handleConfirm
                    : null,
                isLoading: authState.isLoading || _isConfirming,
                height: AppSizes.buttonHeight,
                disabledBackgroundColor: const Color(0xFFA0D488),
              ),
              SizedBox(height: spacing16),

              // ── Resend button ──────────────────────────────────────────────
              PrimaryButton(
                height: AppSizes.buttonHeight,
                text: authState.canResend
                    ? AppStrings.sendAgain
                    : '${AppStrings.sendAgain} (00:${authState.resendTimer.toString().padLeft(2, '0')})',
                onPressed: authState.canResend &&
                        !authState.isResendingOtp &&
                        !authState.isLoading
                    ? _handleResend
                    : null,
                textColor: Colors.white,
                backgroundColor: AppColors.primaryGreen,
                isLoading: authState.isResendingOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
