import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/providers/providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/models/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../provider/upload_image_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // Form fields
  String _name = '';
  String _phoneNumber = '';
  String _building = '';
  String _street = '';
  String _pincode = '';
  String _countryCode = '+91';

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  // Focus nodes
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _buildingFocusNode = FocusNode();
  final FocusNode _streetFocusNode = FocusNode();
  final FocusNode _pincodeFocusNode = FocusNode();

  // Profile image
  File? _profileImage;
  File? _selectedImageForUpload;
  final ImagePicker _picker = ImagePicker();
  String? _uploadedImageUrl;
  bool _isNavigatingToMap = false;

  @override
  void initState() {
    super.initState();
    // Fetch user data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.loadProfile();

    if (success && mounted) {
      _fetchUserData();
    }
  }

  void _fetchUserData() async {
    // Get user data from auth state
     final authState = ref.read(authProvider);

      setState(() {

        _name = authState.name;
        _phoneNumber = authState.phoneNumber;
        _building = authState.buildingNameNumber;
        _street = authState.street;
        _pincode = authState.pincode;

        // Load existing profile image URL from server
        if (authState.imgUrl != null && authState.imgUrl!.isNotEmpty) {
          _uploadedImageUrl = authState.imgUrl;
        }

        // Update controllers
        _nameController.text = _name;
        _phoneController.text = _phoneNumber;
        _buildingController.text = _building;
        _streetController.text = _street;
        _pincodeController.text = _pincode;
      });

  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _buildingController.dispose();
    _streetController.dispose();
    _pincodeController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _buildingFocusNode.dispose();
    _streetFocusNode.dispose();
    _pincodeFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _name.isNotEmpty &&
        _phoneNumber.length == AppSizes.maxLengthPhone &&
        _building.isNotEmpty &&
        _street.isNotEmpty &&
        _pincode.length == AppSizes.maxLengthPincode;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: AppSizes.imageMaxWidth.toDouble(),
        maxHeight: AppSizes.imageMaxHeight.toDouble(),
        imageQuality: AppSizes.imageQuality,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageForUpload = File(pickedFile.path);
        });

        // Show confirmation modal
        _showImageUploadConfirmation();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImageUploadConfirmation() {
    if (_selectedImageForUpload == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ImageUploadConfirmationModal(
        imageFile: _selectedImageForUpload!,
        onConfirm: _uploadImage,
        onCancel: () {
          setState(() {
            _selectedImageForUpload = null;
          });
        },
      ),
    );
  }

  Future<void> _uploadImage() async {
    if (_selectedImageForUpload == null) return;

    try {
      final uploadRepo = ref.read(uploadRepositoryProvider);
      final response = await uploadRepo.uploadImage(
        imageFile: _selectedImageForUpload!,
      );

      if (mounted) {
        // Update profile image and URL
        setState(() {
          _profileImage = _selectedImageForUpload;
          _uploadedImageUrl = response.data.imageUrl;
          _selectedImageForUpload = null;
        });

        // Print image URL to console
        debugPrint('Image URL: ${response.data.imageUrl}');

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');

      if (mounted) {
        setState(() {
          _selectedImageForUpload = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image. Please try again.'),
            backgroundColor: AppColors.errorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
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
        final building = (result['building'] as String? ?? '').trim();
        final streetResult = (result['street'] as String? ?? '').trim();
        final fallbackStreet = (result['fullAddress'] as String? ?? '').trim();
        final pincode = (result['pincode'] as String? ?? '').trim();
        final latitude = (result['latitude'] as num?)?.toDouble();
        final longitude = (result['longitude'] as num?)?.toDouble();

        final streetValue = streetResult.isNotEmpty ? streetResult : fallbackStreet;

        setState(() {
          _building = building;
          _street = streetValue;
          _pincode = pincode;
          _buildingController.text = building;
          _streetController.text = streetValue;
          _pincodeController.text = pincode;
        });

        ref.read(authProvider.notifier).saveAddress(
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
        setState(() => _isNavigatingToMap = false);
      }
    }
  }

  Future<void> _handleSave() async {
    // if (!_isFormValid) return;

    final authNotifier = ref.read(authProvider.notifier);
    final authState = ref.read(authProvider);

    // Update auth state with edited values
    authNotifier.saveName(_name);
    authNotifier.saveImageUrl(_uploadedImageUrl??"");
   // authNotifier.updatePhoneNumber(authState.phoneNumber);
    authNotifier.saveAddress(
      buildingNameNumber: _building,
      street: _street,
      pincode: _pincode,
      latitude: authState.latitude,
      longitude: authState.longitude,
    );

    // Update user profile
    final success = await authNotifier.updateProfile();

    if (success && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate to preferences saved screen
      context.go(RouteNames.preferencesSaved);
    }
    // Error message will be shown via listener
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

    final spacing12 = context.responsiveSpacing(12.0);
    final spacing20 = context.responsiveSpacing(20.0);
    final spacing24 = context.responsiveSpacing(24.0);
    final spacing32 = context.responsiveSpacing(32.0);

    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with green background
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: AppSizes.headerHeight,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF5D9E40), Color(0xFF4A7D33)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Image.asset(
                    "assets/images/header_bg.png",
                    width: MediaQuery.of(context).size.width,
                    height: AppSizes.headerHeight,
                    fit: BoxFit.cover,
                  ),
                ),
            
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            // White rounded container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  // borderRadius: BorderRadius.only(
                  //   topLeft: Radius.circular(context.responsiveSpacing(32.0)),
                  //   topRight: Radius.circular(context.responsiveSpacing(32.0)),
                  // ),
                ),
                child: authState.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      )
                    : SingleChildScrollView(
                  padding: EdgeInsets.all(spacing24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: spacing12),

                      // Title
                      Text(
                        AppStrings.editPersonalProfile,
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(18.0),
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                          fontFamily: 'Lato',
                        ),
                      ),
                      SizedBox(height: spacing12),

                      // Profile Image
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: AppSizes.profileImageWidth,
                              height: AppSizes.profileImageHeight,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  context.responsiveSpacing(20.0),
                                ),
                                image: _profileImage != null
                                    ? DecorationImage(
                                        image: FileImage(_profileImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : _uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(_uploadedImageUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                              ),
                              child: _profileImage == null && (_uploadedImageUrl == null || _uploadedImageUrl!.isEmpty)
                                  ? Icon(
                                      Icons.person,
                                      size: context.responsiveSpacing(80.0),
                                      color: AppColors.primaryGreen,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: EdgeInsets.all(
                                    context.responsiveSpacing(8.0),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primaryGreen,
                                      width: AppSizes.borderThick,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.photo_library,
                                    color: AppColors.primaryGreen,
                                    size: context.responsiveSpacing(12.0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing32),

                      // Name Field
                      _buildLabel('${AppStrings.name} *'),
                      SizedBox(height: spacing12),
                      _buildTextField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        hint: AppStrings.nameHint,
                        onChanged: (value) => setState(() => _name = value),
                        suffixIcon: _name.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: AppSizes.icon20),
                                onPressed: () {
                                  _nameController.clear();
                                  setState(() => _name = '');
                                },
                                color: AppColors.textSecondary,
                              )
                            : null,
                      ),
                      SizedBox(height: spacing12),
                      Text(
                        AppStrings.putYourFirstAndLastName,
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(12.0),
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      SizedBox(height: spacing24),

                      // // Phone Number Field
                      // _buildLabel('${AppStrings.phoneNumber} *'),
                      // SizedBox(height: spacing12),
                      // _buildPhoneField(),
                      // SizedBox(height: spacing12),
                      // Text(
                      //   AppStrings.add10DigitsOnlyProfile,
                      //   style: TextStyle(
                      //     fontSize: context.responsiveFontSize(12.0),
                      //     color: AppColors.textSecondary,
                      //     fontFamily: 'Lato',
                      //   ),
                      // ),
                      //SizedBox(height: spacing24),

                      // Building Name/Number Field
                      _buildLabel('${AppStrings.buildingNameNumber} *'),
                      SizedBox(height: spacing12),
                      _buildTextField(
                        controller: _buildingController,
                        focusNode: _buildingFocusNode,
                        hint: AppStrings.addressHint,
                        onChanged: (value) => setState(() => _building = value),
                      ),
                      SizedBox(height: spacing24),

                      // Street Field
                      _buildLabel('${AppStrings.street} *'),
                      SizedBox(height: spacing12),
                      _buildTextField(
                        controller: _streetController,
                        focusNode: _streetFocusNode,
                        hint: AppStrings.addressHint,
                        onChanged: (value) => setState(() => _street = value),
                      ),
                      SizedBox(height: spacing24),

                      // Pincode Field
                      _buildLabel('${AppStrings.pincode} *'),
                      SizedBox(height: spacing12),
                      _buildTextField(
                        controller: _pincodeController,
                        focusNode: _pincodeFocusNode,
                        hint: AppStrings.addressHint,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (value) => setState(() => _pincode = value),
                      ),
                      SizedBox(height: spacing12),
                      Text(
                        AppStrings.putYourDetailedAddress,
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(12.0),
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      SizedBox(height: spacing24),

                      // Locate on Map Button
                      PrimaryButton(
                        height: context.inputHeight,
                        text: AppStrings.locateOnMap,
                        onPressed: !_isNavigatingToMap ? _handleLocateOnMap : null,
                        textColor: AppColors.textWhite,
                        backgroundColor: const Color(0xFF5D9E40),
                        borderRadius: AppSizes.radius4,
                        isLoading: _isNavigatingToMap,
                      ),
                      SizedBox(height: spacing24),

                      // Save Button
                      PrimaryButton(
                        text: AppStrings.save,
                        onPressed: !authState.isLoading
                            ? _handleSave
                            : null,
                        textColor: Colors.white,
                        height: context.inputHeight,
                        isLoading: authState.isLoading,
                      ),
                      SizedBox(height: spacing20),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: context.responsiveFontSize(14.0),
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        fontFamily: 'Lato',
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required Function(String) onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: context.responsiveFontSize(16.0),
        color: AppColors.textPrimary,
        fontFamily: 'Lato',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: context.responsiveFontSize(16.0),
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          fontFamily: 'Lato',
        ),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.responsiveSpacing(20.0),
          vertical: context.responsiveSpacing(16.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.responsiveSpacing(4.0)),
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: AppSizes.borderMedium,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.responsiveSpacing(AppSizes.radius4)),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: AppSizes.borderThick),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryGreen, width: AppSizes.borderMedium),
        borderRadius: BorderRadius.circular(context.responsiveSpacing(AppSizes.radius4)),
      ),
      child: Row(
        children: [
          // Country Code Picker
          CountryCodePicker(
            onChanged: (country) {
              setState(() {
                _countryCode = country.dialCode ?? '+91';
              });
            },
            initialSelection: 'IN',
            favorite: const ['+91', 'IN'],
            showCountryOnly: false,
            showOnlyCountryWhenClosed: false,
            alignLeft: false,
            padding: EdgeInsets.zero,
            textStyle: TextStyle(
              fontSize: context.responsiveFontSize(16.0),
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
          ),

          // Vertical divider
          Container(
            width: AppSizes.dividerWidth,
            height: context.responsiveSpacing(AppSizes.dividerHeightMedium),
            color: AppColors.borderColor,
          ),

          // Phone number input
          Expanded(
            child: TextField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(AppSizes.maxLengthPhone),
              ],
              onChanged: (value) => setState(() => _phoneNumber = value),
              style: TextStyle(
                fontSize: context.responsiveFontSize(16.0),
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
              decoration: InputDecoration(
                hintText: AppStrings.phoneNumberHint,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: context.responsiveFontSize(16.0),
                                vertical: context.responsiveFontSize(16.0),
                              ),
                              counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageUploadConfirmationModal extends StatefulWidget {
  final File imageFile;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ImageUploadConfirmationModal({
    required this.imageFile,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_ImageUploadConfirmationModal> createState() =>
      _ImageUploadConfirmationModalState();
}

class _ImageUploadConfirmationModalState
    extends State<_ImageUploadConfirmationModal> {
  bool _isUploading = false;

  Future<void> _handleConfirm() async {
    setState(() {
      _isUploading = true;
    });

    // Close the modal first
    Navigator.of(context).pop();

    // Call the confirm callback
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: const Icon(
                    Icons.cloud_upload,
                    color: AppColors.primaryGreen,
                    size: AppSizes.icon24,
                  ),
                ),
                const SizedBox(width: AppSizes.spacing12),
                const Expanded(
                  child: Text(
                    'Upload Profile Image',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize20,
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isUploading
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onCancel();
                        },
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacing20),

            // Image preview
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
                border: Border.all(
                  color: AppColors.borderColor,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radius12 - 2),
                child: Image.file(
                  widget.imageFile,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing20),

            // Confirmation text
            const Text(
              'Are you sure you want to upload this image?',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spacing24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onCancel();
                          },
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSizes.p16),
                      side: const BorderSide(color: AppColors.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      disabledBackgroundColor:
                          AppColors.primaryGreen.withValues(alpha: 0.5),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSizes.p16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                      ),
                    ),
                    icon: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: AppSizes.icon20,
                          ),
                    label: Text(
                      _isUploading ? 'Uploading...' : 'Confirm',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize14,
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
    );
  }
}
