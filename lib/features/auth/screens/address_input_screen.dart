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

class AddressInputScreen extends ConsumerStatefulWidget {
  const AddressInputScreen({super.key});

  @override
  ConsumerState<AddressInputScreen> createState() => _AddressInputScreenState();
}

class _AddressInputScreenState extends ConsumerState<AddressInputScreen> {
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  final FocusNode _buildingFocusNode = FocusNode();
  final FocusNode _floorFocusNode = FocusNode();
  final FocusNode _streetFocusNode = FocusNode();
  final FocusNode _pincodeFocusNode = FocusNode();
  final FocusNode _landmarkFocusNode = FocusNode();

  String _building = '';
  String _floor = '';
  String _street = '';
  String _pincode = '';
  String _landmark = '';
  bool _isNavigatingToMap = false;
  bool _isProcessing = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _buildingController.dispose();
    _floorController.dispose();
    _streetController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    _buildingFocusNode.dispose();
    _floorFocusNode.dispose();
    _streetFocusNode.dispose();
    _pincodeFocusNode.dispose();
    _landmarkFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _building.isNotEmpty &&
        _floor.isNotEmpty &&
        _street.isNotEmpty &&
        _pincode.length == AppSizes.maxLengthPincode &&
        _landmark.isNotEmpty &&
        _latitude != null &&
        _longitude != null;
  }

  Future<void> _handleContinue() async {
    // Concatenate building + floor, and street + landmark
    final buildingFull = '${_building.trim()}, Floor number :  ${_floor.trim()}';
    final streetFull = '${_street.trim()},Landmark :  ${_landmark.trim()}';

    ref.read(authProvider.notifier).saveAddress(
      buildingNameNumber: buildingFull,
      street: streetFull,
      pincode: _pincode.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    setState(() => _isProcessing = true);
    final success =
        await ref.read(authProvider.notifier).completeRegistration();
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration completed successfully!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      context.go(RouteNames.home);
    }
  }

  Future<void> _handleLocateOnMap() async {
    FocusScope.of(context).unfocus();
    setState(() => _isNavigatingToMap = true);

    try {
      final result = await context.push<Map<String, dynamic>>(
        RouteNames.mapPicker,
      );
      if (!mounted) return;

      if (result != null) {
        final lat = (result['latitude'] as num?)?.toDouble();
        final lng = (result['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() {
            _latitude = lat;
            _longitude = lng;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location pinned on map'),
              backgroundColor: AppColors.primaryGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening map picker: $e');
    } finally {
      if (mounted) setState(() => _isNavigatingToMap = false);
    }
  }

  Widget _buildMapLocationIndicator() {
    final isPinned = _latitude != null && _longitude != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isPinned
            ? AppColors.primaryGreen.withValues(alpha: 0.08)
            : AppColors.errorColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(
          color: isPinned
              ? AppColors.primaryGreen.withValues(alpha: 0.35)
              : AppColors.errorColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPinned ? Icons.location_on : Icons.location_off_outlined,
            size: 18,
            color: isPinned ? AppColors.primaryGreen : AppColors.errorColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPinned
                  ? 'Location pinned — tap below to change'
                  : 'Location required — tap below to pin on map',
              style: TextStyle(
                fontSize: context.responsiveFontSize(12.0),
                fontWeight: FontWeight.w500,
                color: isPinned ? AppColors.primaryGreen : AppColors.errorColor,
                fontFamily: 'Lato',
              ),
            ),
          ),
          if (isPinned)
            const Icon(Icons.check_circle, size: 16, color: AppColors.primaryGreen),
        ],
      ),
    );
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
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
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
    final spacing8 = context.responsiveSpacing(8.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing24 = context.responsiveSpacing(24.0);

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
              SizedBox(height: spacing16),
              // Building Name/Number Field
              _buildInputField(
                label: AppStrings.buildingNameNumber,
                controller: _buildingController,
                focusNode: _buildingFocusNode,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                onChanged: (value) {
                  setState(() {
                    _building = value.trim();
                  });
                },
              ),
              SizedBox(height: spacing8),
              // Floor Number Field
              _buildInputField(
                label: AppStrings.floorNumber,
                controller: _floorController,
                focusNode: _floorFocusNode,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _floor = value.trim();
                  });
                },
              ),
              SizedBox(height: spacing8),
              // Street Field
              _buildInputField(
                label: AppStrings.street,
                controller: _streetController,
                focusNode: _streetFocusNode,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                onChanged: (value) {
                  setState(() {
                    _street = value.trim();
                  });
                },
              ),
              SizedBox(height: spacing8),
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
              // Landmark Field
              _buildInputField(
                label: AppStrings.landmark,
                controller: _landmarkController,
                focusNode: _landmarkFocusNode,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                onChanged: (value) {
                  setState(() {
                    _landmark = value.trim();
                  });
                },
              ),
              SizedBox(height: spacing8),
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
              SizedBox(height: spacing8),
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
              // Map location status indicator
              _buildMapLocationIndicator(),
              SizedBox(height: spacing8),
              // Locate on Map Button
              PrimaryButton(
                height: AppSizes.buttonHeight,
                text: AppStrings.locateOnMap,
                onPressed: !_isNavigatingToMap && !_isProcessing
                    ? _handleLocateOnMap
                    : null,
                textColor: AppColors.textWhite,
                backgroundColor: const Color(0xFF5D9E40),
                borderRadius: AppSizes.radius4,
                isLoading: _isNavigatingToMap,
              ),
              SizedBox(height: spacing16),
              // Continue Button
              PrimaryButton(
                text: AppStrings.continueText,
                textColor: Colors.white,
                onPressed: _isFormValid && !_isProcessing && !authState.isLoading
                    ? () { _handleContinue(); }
                    : null,
                isLoading: _isProcessing || authState.isLoading,
                height: AppSizes.buttonHeight,
                disabledBackgroundColor: const Color(0xFFA0D488),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
