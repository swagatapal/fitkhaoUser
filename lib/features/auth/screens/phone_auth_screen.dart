import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:phone_number_hint/phone_number_hint.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../shared/widgets/logo_widget.dart';
import '../../../shared/widgets/primary_button.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  String _result = 'Unknown';
  final _phoneNumberHintPlugin = PhoneNumberHint();


  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleGetCode() async {
    // Validate form before making API call
    final authNotifier = ref.read(authProvider.notifier);

    // Call the send OTP API
    final success = await authNotifier.sendOtp();

    if (success && mounted) {
      // Navigate to OTP verification screen on success
      context.go(RouteNames.otpVerification);
    }
    // Error message will be shown automatically via the error listener
  }

  void _handleAutoFetchPhoneNumber() async {
    // Fetch phone numbers from device SIM cards
    final phoneNumberService = ref.read(phoneNumberServiceProvider);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      ),
    );

    try {
      // Fetch phone numbers
      final List<String> devicePhoneNumbers = await phoneNumberService.fetchPhoneNumbers();

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (devicePhoneNumbers.isEmpty) {
        // No phone numbers found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No phone numbers found on this device'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
        return;
      }

      // Show bottom sheet with phone number options
      if (!mounted) return;

      final selectedPhone = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radius20)),
        ),
        builder: (BuildContext context) {
          return Padding(
            padding: EdgeInsets.all(context.responsiveSpacing(20.0)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.phone_android,
                      color: AppColors.primaryGreen,
                      size: AppSizes.icon24,
                    ),
                    SizedBox(width: context.responsiveSpacing(12.0)),
                    Text(
                      'Select Phone Number',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: context.responsiveFontSize(20.0),
                            fontFamily: 'Lato',
                          ),
                    ),
                  ],
                ),
                SizedBox(height: context.responsiveSpacing(16.0)),
                const Divider(color: AppColors.dividerColor),
                SizedBox(height: context.responsiveSpacing(8.0)),
                ...devicePhoneNumbers.map((phoneNumber) {
                  final formattedNumber = phoneNumberService.formatPhoneNumber(phoneNumber);
                  return ListTile(
                    leading: const Icon(
                      Icons.sim_card,
                      color: AppColors.primaryGreen,
                    ),
                    title: Text(
                      formattedNumber,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: context.responsiveFontSize(16.0),
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Lato',
                          ),
                    ),
                    subtitle: Text(
                      'Tap to use this number',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: context.responsiveFontSize(12.0),
                            color: AppColors.textSecondary,
                            fontFamily: 'Lato',
                          ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: AppSizes.icon16,
                      color: AppColors.textTertiary,
                    ),
                    onTap: () {
                      Navigator.pop(context, phoneNumber);
                    },
                  );
                }),
                SizedBox(height: context.responsiveSpacing(8.0)),
              ],
            ),
          );
        },
      );

      // If a phone number was selected, update the text field
      if (selectedPhone != null && mounted) {
        final digitsOnly = phoneNumberService.extractDigits(selectedPhone);
        _phoneController.text = digitsOnly;
        ref.read(authProvider.notifier).updatePhoneNumber(digitsOnly);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to fetch phone numbers'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

Future<void> getPhoneNumber() async {
    String? result;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      result = await _phoneNumberHintPlugin.requestHint(
              ) ??
          '';
      final phone = getLastTenDigits(result);
    //  final phone = result;
      _phoneController.text = phone;
      ref.read(authProvider.notifier).updatePhoneNumber(phone);

    } on PlatformException {
      result = 'Failed to get hint.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _result = result ?? '';
    });
  }

  String getLastTenDigits(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length <= 10) {
      return digitsOnly;
    }

    return digitsOnly.substring(digitsOnly.length - 10);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Get responsive values
    final horizontalPadding = context.horizontalPadding;
    final verticalPadding = context.verticalPadding;
    final spacing8 = context.responsiveSpacing(8.0);
    final spacing12 = context.responsiveSpacing(12.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing24 = context.responsiveSpacing(24.0);
    final spacing40 = context.responsiveSpacing(40.0);
    final spacing48 = context.responsiveSpacing(48.0);
    final radiusSmall = context.responsiveSpacing(4.0);

    final inputHeight = context.inputHeight;

    // Listen to error messages
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

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
              const Center(
                child: LogoWidget(),
              ),
              SizedBox(height: spacing48),
              // Welcome Text
              Text(
                AppStrings.letsGetStarted,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: context.responsiveFontSize(22.0),
                      fontFamily: "Lato"
                    ),
              ),
              SizedBox(height: spacing8),
              Text(
                AppStrings.enterPhoneNumber,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Color(0xFF2B292A),
                      fontWeight: FontWeight.w400,
                      fontSize: context.responsiveFontSize(16.0),
                      fontFamily: "Lato"
                    ),
              ),
              SizedBox(height: spacing40),
              // Phone Number Input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppStrings.phoneNumberLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: context.responsiveFontSize(14.0),
                              fontFamily: 'Lato',
                            ),
                      ),
                      // const SizedBox(width: AppSizes.spacing4),
                      // Text(
                      //   '*',
                      //   style: TextStyle(
                      //     color: AppColors.errorColor,
                      //     fontSize: context.responsiveFontSize(AppTypography.fontSize16),
                      //   ),
                      // ),
                    ],
                  ),
                  SizedBox(height: spacing8),
                  Container(
                    height: inputHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _phoneFocusNode.hasFocus
                            ? AppColors.inputFocusedBorder
                            : AppColors.inputBorder,
                        width: _phoneFocusNode.hasFocus ? AppSizes.borderThick : AppSizes.borderNormal,
                      ),
                      borderRadius: BorderRadius.circular(radiusSmall),
                    ),
                    child: Row(
                      children: [
                        // Country Code Picker
                        CountryCodePicker(
                          onChanged: (countryCode) {
                            ref
                                .read(authProvider.notifier)
                                .updateCountryCode(countryCode.dialCode ?? '+91');
                          },
                          initialSelection: 'IN',
                          favorite: const ['+91', 'IN'],
                          showCountryOnly: false,
                          showOnlyCountryWhenClosed: false,
                          alignLeft: false,
                          enabled: false,
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing8,
                          ),
                          textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: context.responsiveFontSize(16.0),
                              ),
                          dialogTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: context.responsiveFontSize(14.0),
                              ),
                        ),
                        // Divider
                        Container(
                          height: context.isSmallMobile ? AppSizes.dividerHeight : AppSizes.dividerHeightMedium,
                          width: AppSizes.dividerWidth,
                          color: AppColors.dividerColor,
                        ),
                        // Phone Number Input
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            keyboardType: TextInputType.phone,
                            clipBehavior: Clip.hardEdge,
                            maxLength: AppSizes.maxLengthPhone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              ref
                                  .read(authProvider.notifier)
                                  .updatePhoneNumber(value);
                            },
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontSize: context.responsiveFontSize(16.0),
                            
                                ),
                            decoration: InputDecoration(
                              hintText: AppStrings.phoneNumberHint,
                              border: InputBorder.none,
                              // enabledBorder: InputBorder.none,
                              // focusedBorder: InputBorder.none,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  context.responsiveSpacing(4.0),
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.textWhite,
                                  //width: AppSizes.borderMedium,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  context.responsiveSpacing(4.0),
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.textWhite,
                                  //width: AppSizes.borderMedium,
                                ),
                              ),

                              contentPadding: EdgeInsets.symmetric(
                                horizontal: spacing16,
                                vertical: spacing16,
                              ),
                              counterText: '',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing8),
                  Text(
                    AppStrings.add10DigitsOnly,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: context.responsiveFontSize(12.0),
                          fontFamily: 'Lato',
                        ),
                  ),
                ],
              ),
              SizedBox(height: spacing24),

              // Terms and Conditions
              Container(
                padding: EdgeInsets.all(spacing12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primaryGreen,
                    width: AppSizes.borderMedium,
                  ),
                  borderRadius: BorderRadius.circular(radiusSmall),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.scale(
                      scale: context.isSmallMobile ? 0.9 : 1.0,
                      child: Checkbox(
                        activeColor: AppColors.primaryGreen,
                        value: authState.isTermsAccepted,
                        onChanged: authState.isLoading
                            ? null
                            : (value) {
                          ref
                              .read(authProvider.notifier)
                              .setTermsAccepted(value ?? false);
                        },
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: spacing12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.agreeToTerms,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: context.responsiveFontSize(14.0),
                                  fontFamily: "Lato"
                              ),
                            ),
                            SizedBox(height: spacing8 / 2),
                            GestureDetector(
                              onTap: () {
                                context.push(RouteNames.policy);
                                // TODO: Navigate to Terms and Conditions screen
                                // ScaffoldMessenger.of(context).showSnackBar(
                                //   const SnackBar(
                                //     content: Text(
                                //       'Terms and Conditions screen will be implemented',
                                //     ),
                                //     backgroundColor: AppColors.primaryGreen,
                                //   ),
                                // );
                              },
                              child: Text(
                                AppStrings.readHere,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    fontSize: context.responsiveFontSize(14.0),
                                    fontFamily: "Lato"
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing40),
              // Get Code Button
              PrimaryButton(
                text: "Continue",
                textColor: Colors.white,
                onPressed: authState.phoneNumber.length == AppSizes.maxLengthPhone &&
                        authState.isTermsAccepted &&
                        !authState.isLoading
                    ? _handleGetCode
                    : null,
                isLoading: authState.isLoading,
                height: AppSizes.buttonHeight,
                disabledBackgroundColor: const Color(0xFFA0D488),
                icon: Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: context.isSmallMobile ? AppSizes.icon18 : AppSizes.icon20,
                ),
              ),

              // Auto Fetch Button
              // PrimaryButton(
              //   height: AppSizes.buttonHeight,
              //   text: AppStrings.autoFetchPhoneNumber,
              //   onPressed: authState.isLoading ? null : getPhoneNumber,
              //   textColor: Colors.white,
              //   icon: Icon(
              //     Icons.call_outlined,
              //     size: context.isSmallMobile ? AppSizes.icon18 : AppSizes.icon20,
              //     color: Colors.white,
              //   ),
              // ),


            ],
          ),
        ),
      ),
    );
  }
}
