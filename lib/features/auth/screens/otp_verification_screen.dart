import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final List<TextEditingController> _otpControllers = List.generate(
    AppSizes.maxLengthOTP,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(AppSizes.maxLengthOTP, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // Show OTP message in toast when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.receivedOtpMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.receivedOtpMessage!),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _handleOtpChange(int index, String value) {
    if (value.isNotEmpty) {
      // Move to next field
      if (index < AppSizes.maxLengthOTP - 1) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        // Last field - unfocus
        _otpFocusNodes[index].unfocus();
      }
    }

    // Update the combined OTP value
    final otp = _otpControllers.map((c) => c.text).join();
    ref.read(authProvider.notifier).updateOtp(otp);
  }

  Future<void> _handleConfirm() async {
    final authNotifier = ref.read(authProvider.notifier);

    // Verify OTP
    final response = await authNotifier.verifyOtp();

    if (response != null && mounted) {
      // OTP verified successfully
      debugPrint('[OtpVerificationScreen] OTP verified, registering device...');

      // Register device for push notifications
      // Note: This runs in background and doesn't block navigation
      authNotifier.registerDevice().then((success) {
        if (success) {
          debugPrint('[OtpVerificationScreen] Device registered successfully');
        } else {
          debugPrint('[OtpVerificationScreen] Device registration failed, but continuing...');
        }
      }).catchError((error) {
        debugPrint('[OtpVerificationScreen] Device registration error: $error');
      });

      // Check if user has a profile (name exists in profile)
      final hasProfile = response.user?.name != null &&
                         response.user!.name!.isNotEmpty;

      if (hasProfile) {
        // User has completed profile - navigate to home
        context.go(RouteNames.home);
      } else {
        // User needs to complete profile - navigate to name input
        context.go(RouteNames.nameInput);
      }
    }
    // Error message will be shown automatically via the error listener
  }

  Future<void> _handleResend() async {
    final authNotifier = ref.read(authProvider.notifier);

    // Clear OTP fields
    for (var controller in _otpControllers) {
      controller.clear();
    }

    // Call the resend OTP API
    final success = await authNotifier.resendOtp();

    if (success && mounted) {
      // Focus first field
      _otpFocusNodes[0].requestFocus();

      // Show OTP message in toast
      final authState = ref.read(authProvider);
      if (authState.receivedOtpMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.receivedOtpMessage!),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    // Error message will be shown automatically via the error listener
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for errors
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    // Get responsive values
    final horizontalPadding = context.horizontalPadding;
    final verticalPadding = context.verticalPadding;
    final spacing12 = context.responsiveSpacing(12.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing32 = context.responsiveSpacing(32.0);
    final spacing40 = context.responsiveSpacing(40.0);
    final spacing48 = context.responsiveSpacing(48.0);
    final radiusSmall = context.responsiveSpacing(4.0);

    final otpBoxSize = context.isSmallMobile ? 40.0 : 50.0;

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
              // Logo
              const Center(child: LogoWidget()),
              SizedBox(height: spacing48),
              // Title
              Text(
                AppStrings.confirmPhoneNumber,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: context.responsiveFontSize(22.0),
                  fontFamily: "Lato",
                ),
              ),
              SizedBox(height: spacing16),
              // Subtitle with phone number
              RichText(
                text: TextSpan(
                  text: AppStrings.confirmationCodeSent,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF2B292A),
                    fontWeight: FontWeight.w400,
                    fontSize: context.responsiveFontSize(16.0),
                    fontFamily: "Lato",
                  ),
                  children: [
                    TextSpan(
                      text:
                          '\n${authState.countryCode} ${authState.phoneNumber}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: context.responsiveFontSize(16.0),
                        fontFamily: "Lato",
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing40),
              // Code Label
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
              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(AppSizes.maxLengthOTP, (index) {
                  final hasFocus = _otpFocusNodes[index].hasFocus;
                  final hasValue = _otpControllers[index].text.isNotEmpty;

                  return Container(
                    width: otpBoxSize,
                    height: otpBoxSize,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.textWhite
                      ),
                      borderRadius: BorderRadius.circular(radiusSmall),
                     // color: AppColors.inputBackground,
                    ),
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: AppSizes.maxLengthOTPDigit,
                      enabled: !authState.isLoading,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: context.responsiveFontSize(16.0),
                            fontFamily: 'Lato',
                          ),
                      decoration: InputDecoration(
                        counterText: "",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: context.responsiveSpacing(10.0),
                          vertical: context.responsiveSpacing(8.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            context.responsiveSpacing(4.0),
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.borderColor,
                            width: AppSizes.borderMedium,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            context.responsiveSpacing(4.0),
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGreen,
                            width: AppSizes.borderMedium,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        _handleOtpChange(index, value);
                        setState(() {}); // Update border color
                      },
                      onTap: () {
                        setState(() {}); // Update focus state
                      },
                      onEditingComplete: () {
                        setState(() {}); // Update focus state
                      },
                      onSubmitted: (value) {
                        setState(() {}); // Update focus state
                      },
                    ),
                  );
                }),
              ),
              SizedBox(height: spacing32),
              // Confirm Button
              PrimaryButton(
                text: AppStrings.confirm,
                textColor: Colors.white,
                onPressed: authState.otp.length == AppSizes.maxLengthOTP && !authState.isLoading
                    ? _handleConfirm
                    : null,
                isLoading: authState.isLoading,
                height: AppSizes.buttonHeight,
                disabledBackgroundColor: const Color(0xFFA0D488),
              ),
              SizedBox(height: spacing16),
              // Send Again Button with 60s lockout
              PrimaryButton(
                height: AppSizes.buttonHeight,
                text: authState.canResend
                    ? AppStrings.sendAgain
                    : '${AppStrings.sendAgain} (00:${authState.resendTimer.toString().padLeft(2, '0')})',
                onPressed: authState.canResend && !authState.isResendingOtp && !authState.isLoading
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
