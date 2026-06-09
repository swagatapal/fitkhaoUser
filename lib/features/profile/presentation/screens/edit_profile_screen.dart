import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/responsive_utils.dart';
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
  String _building = '';
  String _floor = '';
  String _street = '';
  String _pincode = '';
  String _landmark = '';

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  // Focus nodes
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _buildingFocusNode = FocusNode();
  final FocusNode _floorFocusNode = FocusNode();
  final FocusNode _streetFocusNode = FocusNode();
  final FocusNode _pincodeFocusNode = FocusNode();
  final FocusNode _landmarkFocusNode = FocusNode();

  // Profile image
  File? _profileImage;
  File? _selectedImageForUpload;
  final ImagePicker _picker = ImagePicker();
  String? _uploadedImageUrl;
  bool _isNavigatingToMap = false;
  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;
  double? _latitude;
  double? _longitude;

  static const String _floorMarker = 'Floor number :';
  static const String _landmarkMarker = 'Landmark :';

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
    if (!mounted) return;

    if (success) {
      _populateFormFromState(ref.read(authProvider));
    }

    setState(() => _isLoadingProfile = false);
  }

  void _populateFormFromState(AuthState authState) {
    final buildingParts = _splitCompositeAddressField(
      authState.buildingNameNumber,
      _floorMarker,
    );
    final streetParts = _splitCompositeAddressField(
      authState.street,
      _landmarkMarker,
    );

    setState(() {
      _name = authState.name;
      _building = buildingParts.primary;
      _floor = buildingParts.secondary;
      _street = streetParts.primary;
      _landmark = streetParts.secondary;
      _pincode = authState.pincode;
      _latitude = authState.latitude;
      _longitude = authState.longitude;
      _uploadedImageUrl = authState.imgUrl;

      _nameController.text = _name;
      _buildingController.text = _building;
      _floorController.text = _floor;
      _streetController.text = _street;
      _pincodeController.text = _pincode;
      _landmarkController.text = _landmark;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _streetController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    _nameFocusNode.dispose();
    _buildingFocusNode.dispose();
    _floorFocusNode.dispose();
    _streetFocusNode.dispose();
    _pincodeFocusNode.dispose();
    _landmarkFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _name.trim().isNotEmpty ;
        // &&
        // _building.trim().isNotEmpty &&
        // _floor.trim().isNotEmpty &&
        // _street.trim().isNotEmpty &&
        // _pincode.trim().length == AppSizes.maxLengthPincode &&
        // _landmark.trim().isNotEmpty &&
        // _latitude != null &&
        // _longitude != null;
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
        final latitude = (result['latitude'] as num?)?.toDouble();
        final longitude = (result['longitude'] as num?)?.toDouble();

        if (latitude != null && longitude != null) {
          setState(() {
            _latitude = latitude;
            _longitude = longitude;
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
      if (mounted) {
        setState(() => _isNavigatingToMap = false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_isFormValid || _isSavingProfile) return;

    final authNotifier = ref.read(authProvider.notifier);
    final authState = ref.read(authProvider);
    final buildingFull = _composeCompositeAddressField(
      primary: _building,
      secondary: _floor,
      marker: _floorMarker,
    );
    final streetFull = _composeCompositeAddressField(
      primary: _street,
      secondary: _landmark,
      marker: _landmarkMarker,
    );

    authNotifier.saveName(_name.trim());
    authNotifier.saveImageUrl(
      (_uploadedImageUrl ?? authState.imgUrl ?? '').trim(),
    );
    authNotifier.saveAddress(
      buildingNameNumber: buildingFull,
      street: streetFull,
      pincode: _pincode.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    setState(() => _isSavingProfile = true);
    final success = await authNotifier.updateProfile();
    if (!mounted) return;
    setState(() => _isSavingProfile = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      context.go(RouteNames.preferencesSaved);
    }
  }

  _CompositeAddressParts _splitCompositeAddressField(
    String value,
    String marker,
  ) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      return const _CompositeAddressParts(primary: '', secondary: '');
    }

    final markerIndex = normalizedValue.toLowerCase().indexOf(
          marker.toLowerCase(),
        );

    if (markerIndex == -1) {
      return _CompositeAddressParts(
        primary: normalizedValue,
        secondary: '',
      );
    }

    final primary = normalizedValue
        .substring(0, markerIndex)
        .trim()
        .replaceFirst(RegExp(r'[,\s]+$'), '');
    final secondary = normalizedValue
        .substring(markerIndex + marker.length)
        .trim()
        .replaceFirst(RegExp(r'^,+'), '')
        .trim();

    return _CompositeAddressParts(
      primary: primary,
      secondary: secondary,
    );
  }

  String _composeCompositeAddressField({
    required String primary,
    required String secondary,
    required String marker,
  }) {
    return '${primary.trim()}, $marker ${secondary.trim()}';
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
            const Icon(
              Icons.check_circle,
              size: 16,
              color: AppColors.primaryGreen,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F4),
        body: Stack(
          children: [
            Column(
              children: [
                _isLoadingProfile
                    ? Expanded(
                        child: Column(
                          children: [
                            _buildHeaderOnly(),
                            const Expanded(
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Expanded(
                        child: Column(
                          children: [
                            _buildHeaderOnly(),
                            Expanded(
                              child: CustomScrollView(
                                physics: const BouncingScrollPhysics(),
                                slivers: [
                                  SliverPadding(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 72, 16, 24),
                                    sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionCard(
                                  icon: Icons.person_outline_rounded,
                                  title: 'Personal Information',
                                  children: [
                                    _field(
                                      label: '${AppStrings.name} *',
                                      helper: AppStrings
                                          .putYourFirstAndLastName,
                                      child: _buildTextField(
                                        controller: _nameController,
                                        focusNode: _nameFocusNode,
                                        hint: AppStrings.nameHint,
                                        prefixIcon: Icons.badge_outlined,
                                        onChanged: (value) =>
                                            setState(() => _name = value),
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .deny(
                                            RegExp(
                                              r'(\u00a9|\u00ae|[\u2000-\u3300]|'
                                              r'\ud83c[\ud000-\udfff]|'
                                              r'\ud83d[\ud000-\udfff]|'
                                              r'\ud83e[\ud000-\udfff])',
                                            ),
                                          ),
                                        ],
                                        suffixIcon: _name.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                    Icons.clear,
                                                    size:
                                                        AppSizes.icon20),
                                                onPressed: () {
                                                  _nameController.clear();
                                                  setState(
                                                      () => _name = '');
                                                },
                                                color: AppColors
                                                    .textSecondary,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    _field(label: "Phone number (can not editable)", child: Text(authState.phoneNumber))


                                  ],
                                ),
                                const SizedBox(height: 16),
                                // _sectionCard(
                                //   icon: Icons.location_on_outlined,
                                //   title: 'Your Home Address',
                                //   children: [
                                //     _field(
                                //       label:
                                //           '${AppStrings.buildingNameNumber} *',
                                //       child: _buildTextField(
                                //         controller: _buildingController,
                                //         focusNode: _buildingFocusNode,
                                //         hint:
                                //             AppStrings.buildingNameNumber,
                                //         prefixIcon:
                                //             Icons.apartment_rounded,
                                //         inputFormatters: [
                                //           FilteringTextInputFormatter
                                //               .deny(
                                //             RegExp(
                                //               r'(\u00a9|\u00ae|[\u2000-\u3300]|'
                                //               r'\ud83c[\ud000-\udfff]|'
                                //               r'\ud83d[\ud000-\udfff]|'
                                //               r'\ud83e[\ud000-\udfff])',
                                //             ),
                                //           ),
                                //         ],
                                //         onChanged: (value) => setState(
                                //             () =>
                                //                 _building = value.trim()),
                                //       ),
                                //     ),
                                //     const SizedBox(height: 16),
                                //     Row(
                                //       crossAxisAlignment:
                                //           CrossAxisAlignment.start,
                                //       children: [
                                //         Expanded(
                                //           child: _field(
                                //             label:
                                //                 '${AppStrings.floorNumber} *',
                                //             child: _buildTextField(
                                //               controller:
                                //                   _floorController,
                                //               focusNode: _floorFocusNode,
                                //               hint:
                                //                   AppStrings.floorNumber,
                                //               prefixIcon:
                                //                   Icons.stairs_outlined,
                                //               keyboardType:
                                //                   TextInputType.number,
                                //               inputFormatters: [
                                //                 FilteringTextInputFormatter
                                //                     .digitsOnly,
                                //               ],
                                //               onChanged: (value) =>
                                //                   setState(() => _floor =
                                //                       value.trim()),
                                //             ),
                                //           ),
                                //         ),
                                //         const SizedBox(width: 12),
                                //         Expanded(
                                //           child: _field(
                                //             label:
                                //                 '${AppStrings.pincode} *',
                                //             child: _buildTextField(
                                //               controller:
                                //                   _pincodeController,
                                //               focusNode:
                                //                   _pincodeFocusNode,
                                //               hint: AppStrings.pincode,
                                //               prefixIcon:
                                //                   Icons.pin_drop_outlined,
                                //               keyboardType:
                                //                   TextInputType.number,
                                //               inputFormatters: [
                                //                 FilteringTextInputFormatter
                                //                     .digitsOnly,
                                //                 LengthLimitingTextInputFormatter(
                                //                     6),
                                //               ],
                                //               onChanged: (value) =>
                                //                   setState(() =>
                                //                       _pincode =
                                //                           value.trim()),
                                //             ),
                                //           ),
                                //         ),
                                //       ],
                                //     ),
                                //     const SizedBox(height: 16),
                                //     _field(
                                //       label: '${AppStrings.street} *',
                                //       child: _buildTextField(
                                //         controller: _streetController,
                                //         focusNode: _streetFocusNode,
                                //         hint: AppStrings.street,
                                //         prefixIcon:
                                //             Icons.signpost_outlined,
                                //         inputFormatters: [
                                //           FilteringTextInputFormatter
                                //               .deny(
                                //             RegExp(
                                //               r'(\u00a9|\u00ae|[\u2000-\u3300]|'
                                //               r'\ud83c[\ud000-\udfff]|'
                                //               r'\ud83d[\ud000-\udfff]|'
                                //               r'\ud83e[\ud000-\udfff])',
                                //             ),
                                //           ),
                                //         ],
                                //         onChanged: (value) => setState(
                                //             () => _street = value.trim()),
                                //       ),
                                //     ),
                                //     const SizedBox(height: 16),
                                //     _field(
                                //       label: '${AppStrings.landmark} *',
                                //       helper: AppStrings
                                //           .putYourDetailedAddress,
                                //       child: _buildTextField(
                                //         controller: _landmarkController,
                                //         focusNode: _landmarkFocusNode,
                                //         hint: AppStrings.landmark,
                                //         prefixIcon: Icons.place_outlined,
                                //         inputFormatters: [
                                //           FilteringTextInputFormatter
                                //               .deny(
                                //             RegExp(
                                //               r'(\u00a9|\u00ae|[\u2000-\u3300]|'
                                //               r'\ud83c[\ud000-\udfff]|'
                                //               r'\ud83d[\ud000-\udfff]|'
                                //               r'\ud83e[\ud000-\udfff])',
                                //             ),
                                //           ),
                                //         ],
                                //         onChanged: (value) => setState(
                                //             () =>
                                //                 _landmark = value.trim()),
                                //       ),
                                //     ),
                                //     const SizedBox(height: 16),
                                //     _buildMapLocationIndicator(),
                                //     const SizedBox(height: 12),
                                //     PrimaryButton(
                                //       height: context.inputHeight,
                                //       text: AppStrings.locateOnMap,
                                //       onPressed: !_isNavigatingToMap &&
                                //               !_isSavingProfile
                                //           ? _handleLocateOnMap
                                //           : null,
                                //       textColor: AppColors.textWhite,
                                //       backgroundColor:
                                //           const Color(0xFF5D9E40),
                                //       borderRadius: AppSizes.radius8,
                                //       isLoading: _isNavigatingToMap,
                                //     ),
                                //   ],
                                // ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 80),
                          sliver: SliverToBoxAdapter(child: Container()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ),
                if (!_isLoadingProfile) _buildBottomSaveBar(authState),
              ],
            ),
            if (!_isLoadingProfile)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildAvatarOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderOnly() {
    final headerHeight = MediaQuery.of(context).size.height * 0.1;

    return SizedBox(
      height: headerHeight,
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Container(
          height: headerHeight,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5D9E40), Color(0xFF4A7D33)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/images/header_bg.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(top: -24, right: -16, child: _circle(110, 0.08)),
              Positioned(bottom: 10, left: -20, child: _circle(70, 0.06)),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.pop(),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: AppSizes.icon20),
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
      ),
    );
  }

  Widget _buildAvatarOverlay() {
    final headerHeight = MediaQuery.of(context).size.height * 0.1;
    const avatarRadius = 52.0;

    return Padding(
      padding: EdgeInsets.only(top: headerHeight - avatarRadius),
      child: Center(child: _buildAvatar(avatarRadius)),
    );
  }


  Widget _buildAvatar(double radius) {
    final hasFile = _profileImage != null;
    final hasUrl = _uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
            backgroundImage: hasFile
                ? FileImage(_profileImage!)
                : hasUrl
                    ? NetworkImage(_uploadedImageUrl!) as ImageProvider
                    : null,
            child: (!hasFile && !hasUrl)
                ? Icon(Icons.person_rounded,
                    size: radius, color: AppColors.primaryGreen)
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: AppSizes.icon16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  // \u2500\u2500\u2500 Section card \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                child: Icon(icon, color: AppColors.primaryGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize15,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// Label + field (+ optional helper text), used inside section cards.
  Widget _field({
    required String label,
    required Widget child,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        child,
        if (helper != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              helper,
              style: TextStyle(
                fontSize: context.responsiveFontSize(11.5),
                color: AppColors.textTertiary,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomSaveBar(AuthState authState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: PrimaryButton(
            text: AppStrings.save,
            onPressed: _isFormValid && !_isSavingProfile && !authState.isLoading
                ? _handleSave
                : null,
            textColor: Colors.white,
            height: context.inputHeight,
            borderRadius: AppSizes.radius8,
            isLoading: _isSavingProfile,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: context.responsiveFontSize(13.0),
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontFamily: 'Lato',
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required Function(String) onChanged,
    IconData? prefixIcon,
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
        fontSize: context.responsiveFontSize(15.0),
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        fontFamily: 'Lato',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: context.responsiveFontSize(14.0),
          color: AppColors.textTertiary,
          fontFamily: 'Lato',
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon,
                size: AppSizes.icon20, color: AppColors.textSecondary)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF6F8F6),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          borderSide: const BorderSide(color: Color(0xFFE6E9E6), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          borderSide:
              const BorderSide(color: AppColors.primaryGreen, width: 1.6),
        ),
      ),
    );
  }
}

class _CompositeAddressParts {
  final String primary;
  final String secondary;

  const _CompositeAddressParts({
    required this.primary,
    required this.secondary,
  });
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
