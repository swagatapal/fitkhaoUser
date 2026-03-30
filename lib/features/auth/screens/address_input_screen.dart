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
import '../providers/auth_provider.dart';

class AddressInputScreen extends ConsumerStatefulWidget {
  const AddressInputScreen({super.key});

  @override
  ConsumerState<AddressInputScreen> createState() => _AddressInputScreenState();
}

class _AddressInputScreenState extends ConsumerState<AddressInputScreen> {
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  final FocusNode _buildingFocusNode = FocusNode();
  final FocusNode _streetFocusNode = FocusNode();
  final FocusNode _pincodeFocusNode = FocusNode();

  String _building = '';
  String _street = '';
  String _pincode = '';
  bool _isNavigatingToMap = false;
  String? _selectedAddressType;

  final List<Map<String, dynamic>> _addressTypes = const [
    {'label': 'Home', 'icon': Icons.home_outlined},
    {'label': 'Work', 'icon': Icons.work_outline},
    {'label': 'Other', 'icon': Icons.location_on_outlined},
  ];

  @override
  void dispose() {
    _buildingController.dispose();
    _streetController.dispose();
    _pincodeController.dispose();
    _buildingFocusNode.dispose();
    _streetFocusNode.dispose();
    _pincodeFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _building.isNotEmpty &&
        _street.isNotEmpty &&
        _pincode.length == AppSizes.maxLengthPincode;
  }

  void _handleContinue() {
    // Save address to auth provider
    ref
        .read(authProvider.notifier)
        .saveAddress(
          buildingNameNumber: _building,
          street: _street,
          pincode: _pincode,
        );

    // Navigate to BMI analysis screen
    context.go(RouteNames.bmiAnalysis);
  }

  Future<void> _handleLocateOnMap() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isNavigatingToMap = true;
    });

    try {
      final result = await context.push<Map<String, dynamic>>(
        RouteNames.mapPicker,
      );
      if (!mounted) {
        return;
      }

      if (result != null) {
        print(result.toString());
        final building = (result['building'] as String? ?? '').trim();
        final streetResult = (result['street'] as String? ?? '').trim();
        final fallbackStreet = (result['fullAddress'] as String? ?? '').trim();
        final pincode = (result['pincode'] as String? ?? '').trim();
        final latitude = (result['latitude'] as num?)?.toDouble();
        final longitude = (result['longitude'] as num?)?.toDouble();

        final streetValue = streetResult.isNotEmpty
            ? streetResult
            : fallbackStreet;

        setState(() {
          _building = building;
          _street = streetValue;
          _pincode = pincode;
          _buildingController.text = building;
          _streetController.text = streetValue;
          _pincodeController.text = pincode;
        });

        ref
            .read(authProvider.notifier)
            .saveAddress(
              buildingNameNumber: building,
              street: streetValue,
              pincode: pincode,
              latitude: latitude,
              longitude: longitude,
            );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address selected from map'),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening map picker: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isNavigatingToMap = false;
        });
      }
    }
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Function(String) onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    final spacing8 = context.responsiveSpacing(8.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
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
        SizedBox(height: spacing8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          onChanged: onChanged,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: context.responsiveFontSize(14.0),
            fontFamily: 'Lato',
          ),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(
              fontSize: context.responsiveFontSize(16.0),
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.responsiveSpacing(16.0),
              vertical: context.responsiveSpacing(12.0),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive values
    final horizontalPadding = context.horizontalPadding;
    final verticalPadding = context.verticalPadding;
    final spacing8 = context.responsiveSpacing(8.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing24 = context.responsiveSpacing(24.0);
    final spacing40 = context.responsiveSpacing(40.0);
    final spacing48 = context.responsiveSpacing(48.0);

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
              SizedBox(height: spacing24),
              // Logo
              const Center(child: LogoWidget()),
              SizedBox(height: spacing24),
              // Title
              Text(
                AppStrings.whereToDeliver,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: context.responsiveFontSize(22.0),
                  fontFamily: "Lato",
                ),
              ),
              SizedBox(height: spacing8),
              // Subtitle
              Text(
                AppStrings.pleaseEnterAddress,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF2B292A),
                  fontWeight: FontWeight.w400,
                  fontSize: context.responsiveFontSize(16.0),
                  fontFamily: "Lato",
                ),
              ),
              SizedBox(height: spacing40),
              // Building Name/Number Field
              _buildInputField(
                label: AppStrings.buildingNameNumber,
                controller: _buildingController,
                focusNode: _buildingFocusNode,
                onChanged: (value) {
                  setState(() {
                    _building = value.trim();
                  });
                },
              ),
              SizedBox(height: spacing16),
              // Street Field
              _buildInputField(
                label: AppStrings.street,
                controller: _streetController,
                focusNode: _streetFocusNode,
                onChanged: (value) {
                  setState(() {
                    _street = value.trim();
                  });
                },
              ),
              SizedBox(height: spacing16),
              // Pincode Field
              _buildInputField(
                label: AppStrings.pincode,
                controller: _pincodeController,
                focusNode: _pincodeFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: AppSizes.maxLengthPincode,
                onChanged: (value) {
                  setState(() {
                    _pincode = value.trim();
                  });
                },
              ),
              //  SizedBox(height: spacing8),
              // Helper text
              Text(
                AppStrings.putYourDetailedAddress,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: context.responsiveFontSize(12.0),
                  fontFamily: 'Lato',
                ),
              ),
              SizedBox(height: spacing24),
              // Address Type Dropdown
              // Column(
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   children: [
              //     Row(
              //       children: [
              //         Text(
              //           'Choose your kitchen',
              //           style: Theme.of(context).textTheme.labelLarge?.copyWith(
              //             color: AppColors.textPrimary,
              //             fontWeight: FontWeight.w600,
              //             fontSize: context.responsiveFontSize(14.0),
              //             fontFamily: 'Lato',
              //           ),
              //         ),
              //         const SizedBox(width: AppSizes.spacing4),
              //         Text(
              //           '*',
              //           style: TextStyle(
              //             color: AppColors.errorColor,
              //             fontSize: context.responsiveFontSize(AppTypography.fontSize16),
              //           ),
              //         ),
              //       ],
              //     ),
              //     SizedBox(height: spacing8),
              //     DropdownButtonFormField<String>(
              //       value: _selectedAddressType,
              //       icon: const Icon(
              //         Icons.keyboard_arrow_down_rounded,
              //         color: AppColors.textSecondary,
              //       ),
              //       dropdownColor: Colors.white,
              //       style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              //         fontSize: context.responsiveFontSize(14.0),
              //         fontFamily: 'Lato',
              //         color: AppColors.textPrimary,
              //       ),
              //       decoration: InputDecoration(
              //         hintText: 'Select nearest kitchen',
              //         hintStyle: TextStyle(
              //           fontSize: context.responsiveFontSize(14.0),
              //           color: AppColors.textSecondary,
              //           fontFamily: 'Lato',
              //         ),
              //         filled: true,
              //         fillColor: Colors.white,
              //         contentPadding: EdgeInsets.symmetric(
              //           horizontal: context.responsiveSpacing(16.0),
              //           vertical: context.responsiveSpacing(12.0),
              //         ),
              //         enabledBorder: OutlineInputBorder(
              //           borderRadius: BorderRadius.circular(
              //             context.responsiveSpacing(4.0),
              //           ),
              //           borderSide: const BorderSide(
              //             color: AppColors.borderColor,
              //             width: AppSizes.borderMedium,
              //           ),
              //         ),
              //         focusedBorder: OutlineInputBorder(
              //           borderRadius: BorderRadius.circular(
              //             context.responsiveSpacing(4.0),
              //           ),
              //           borderSide: const BorderSide(
              //             color: AppColors.primaryGreen,
              //             width: AppSizes.borderMedium,
              //           ),
              //         ),
              //       ),
              //       onChanged: (value) {
              //         setState(() {
              //           _selectedAddressType = value;
              //         });
              //       },
              //       items: _addressTypes
              //           .map(
              //             (t) => DropdownMenuItem<String>(
              //               value: t['label'] as String,
              //               child: Row(
              //                 children: [
              //                   Icon(
              //                     t['icon'] as IconData,
              //                     color: AppColors.primaryGreen,
              //                     size: context.responsiveFontSize(20.0),
              //                   ),
              //                   SizedBox(
              //                     width: context.responsiveSpacing(12.0),
              //                   ),
              //                   Text(
              //                     t['label'] as String,
              //                     style: Theme.of(context).textTheme.bodyLarge
              //                         ?.copyWith(
              //                           fontSize: context.responsiveFontSize(
              //                             16.0,
              //                           ),
              //                           fontFamily: 'Lato',
              //                         ),
              //                   ),
              //                 ],
              //               ),
              //             ),
              //           )
              //           .toList(),
              //     ),
              //     SizedBox(height: spacing8),
              //     Text(
              //       "Select your nearest Fitkhao kitchen to get fatest delivery",
              //       style: Theme.of(context).textTheme.bodySmall?.copyWith(
              //         color: AppColors.textTertiary,
              //         fontSize: context.responsiveFontSize(12.0),
              //         fontFamily: 'Lato',
              //       ),
              //     ),
              //   ],
              // ),
              // SizedBox(height: spacing24),
              // Continue Button
              PrimaryButton(
                text: AppStrings.continueText,
                textColor: Colors.white,
                onPressed: _isFormValid ? _handleContinue : null,
                isLoading: false,
                height: AppSizes.buttonHeight,
                disabledBackgroundColor: const Color(0xFFA0D488),
              ),
              SizedBox(height: spacing16),
              // Locate on Map Button
              PrimaryButton(
                height: AppSizes.buttonHeight,
                text: AppStrings.locateOnMap,
                onPressed: !_isNavigatingToMap ? _handleLocateOnMap : null,
                textColor: AppColors.textWhite,
                backgroundColor: Color(0XFF5D9E40),
                borderRadius: AppSizes.radius4,
                isLoading: _isNavigatingToMap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
