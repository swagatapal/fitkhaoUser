import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/delivery_address_model.dart';
import '../../providers/delivery_address_provider.dart';

/// Dark status-bar icons so the system bar stays visible over the white header.
const SystemUiOverlayStyle _kHeaderOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark, // Android
  statusBarBrightness: Brightness.light, // iOS
);

/// Add / edit a delivery address.
///
/// Pass [existing] to edit; omit it to create a new address. Coordinates are
/// captured from the shared map picker ([RouteNames.mapPicker]).
class AddressFormScreen extends ConsumerStatefulWidget {
  final DeliveryAddressModel? existing;

  const AddressFormScreen({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late final TextEditingController _buildingName;
  late final TextEditingController _street;
  late final TextEditingController _area;
  late final TextEditingController _city;
  late final TextEditingController _pincode;
  late final TextEditingController _floor;
  late final TextEditingController _room;
  late final TextEditingController _landmark;
  late final TextEditingController _contact;
  late final TextEditingController _instructions;

  static const _labels = ['home', 'work', 'other'];
  String _label = 'home';
  bool _isDefault = false;
  bool _isSaving = false;

  // ── Coordinates captured from the map picker ──────────────────────────────
  double? _latitude;
  double? _longitude;
  String _mapAddressLabel = '';
  bool _locationError = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _buildingName = TextEditingController(text: e?.buildingName ?? '');
    _street = TextEditingController(text: e?.street ?? '');
    _area = TextEditingController(text: e?.area ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _pincode = TextEditingController(text: e?.pincode ?? '');
    _floor = TextEditingController(text: e?.floorNumber ?? '');
    _room = TextEditingController(text: e?.roomNumber ?? '');
    _landmark = TextEditingController(text: e?.landmark ?? '');
    _instructions = TextEditingController(text: e?.deliveryInstructions ?? '');

    final fallbackPhone = ref.read(authProvider).phoneNumber;
    _contact = TextEditingController(text: e?.contactNumber ?? fallbackPhone);

    _label = (e != null && _labels.contains(e.label)) ? e.label : 'home';
    _isDefault = e?.isDefault ?? false;

    // Seed coordinates when editing an existing address.
    if (e != null && (e.latitude != 0.0 || e.longitude != 0.0)) {
      _latitude = e.latitude;
      _longitude = e.longitude;
      _mapAddressLabel = e.formattedAddress;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _buildingName.dispose();
    _street.dispose();
    _area.dispose();
    _city.dispose();
    _pincode.dispose();
    _floor.dispose();
    _room.dispose();
    _landmark.dispose();
    _contact.dispose();
    _instructions.dispose();
    super.dispose();
  }

  bool get _hasLocation => _latitude != null && _longitude != null;

  // ── Map picker ────────────────────────────────────────────────────────────

  Future<void> _openMapPicker() async {
    FocusScope.of(context).unfocus();
    final result =
        await context.push<Map<String, dynamic>>(RouteNames.mapPicker);
    if (!mounted || result == null) return;

    final lat = (result['latitude'] as num?)?.toDouble();
    final lng = (result['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    setState(() {
      _latitude = lat;
      _longitude = lng;
      _locationError = false;
      _mapAddressLabel = (result['fullAddress'] as String?)?.trim() ?? '';

      // Convenience auto-fill — only into empty fields, never overwriting edits.
      final pincode = (result['pincode'] as String?)?.trim() ?? '';
      if (pincode.isNotEmpty && _pincode.text.trim().isEmpty) {
        _pincode.text = pincode;
      }
      final building = (result['building'] as String?)?.trim() ?? '';
      if (building.isNotEmpty && _buildingName.text.trim().isEmpty) {
        _buildingName.text = building;
      }
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final formValid = _formKey.currentState!.validate();

    if (!_hasLocation) {
      setState(() => _locationError = true);
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _showSnack('Please select your location on the map', isError: true);
      return;
    }
    if (!formValid) return;

    FocusScope.of(context).unfocus();
    final existing = widget.existing;

    final model = DeliveryAddressModel(
      id: existing?.id ?? '',
      label: _label,
      buildingName: _buildingName.text.trim(),
      street: _street.text.trim(),
      area: _area.text.trim(),
      city: _city.text.trim(),
      pincode: _pincode.text.trim(),
      latitude: _latitude!,
      longitude: _longitude!,
      floorNumber: _floor.text.trim(),
      roomNumber: _room.text.trim(),
      landmark: _landmark.text.trim(),
      contactNumber: _contact.text.trim(),
      deliveryInstructions: _instructions.text.trim(),
      isDefault: _isDefault,
    );

    setState(() => _isSaving = true);

    final notifier = ref.read(addressProvider.notifier);
    final result = widget.isEditing
        ? await notifier.updateAddress(existing!.id, model)
        : await notifier.addAddress(model);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      Navigator.of(context).pop();
      _showSnack(widget.isEditing
          ? 'Address updated successfully'
          : 'Address added successfully');
    } else {
      _showSnack(
        result.message.isNotEmpty
            ? result.message
            : 'Something went wrong. Please try again.',
        isError: true,
      );
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.errorColor : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
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
            onTap: () => Navigator.of(context).maybePop(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Edit Address' : 'Add Address',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _kHeaderOverlay,
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(AppSizes.spacing16,
                      AppSizes.spacing16, AppSizes.spacing16, AppSizes.spacing32),
                  children: [
            // ── Location ──────────────────────────────────────────────────
            _SectionCard(
              icon: Icons.map_outlined,
              title: 'Delivery Location',
              child: _LocationPickerTile(
                hasLocation: _hasLocation,
                addressLabel: _mapAddressLabel,
                latitude: _latitude,
                longitude: _longitude,
                hasError: _locationError,
                onTap: _openMapPicker,
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),

            // ── Address details ───────────────────────────────────────────
            _SectionCard(
              icon: Icons.home_work_outlined,
              title: 'Address Details',
              child: Column(
                children: [
                  _field(
                    controller: _buildingName,
                    label: 'Building / Flat / House',
                    hint: 'e.g. 47, Nursing Home',
                    icon: Icons.apartment_rounded,
                    required: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  _field(
                    controller: _street,
                    label: 'Street / Road',
                    hint: 'e.g. Strand Road',
                    icon: Icons.signpost_outlined,
                    required: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          controller: _floor,
                          label: 'Floor',
                          hint: 'e.g. 1',
                          icon: Icons.stairs_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacing12),
                      Expanded(
                        child: _field(
                          controller: _room,
                          label: 'Room',
                          hint: 'e.g. 101',
                          icon: Icons.meeting_room_outlined,
                        ),
                      ),
                    ],
                  ),
                  _field(
                    controller: _area,
                    label: 'Area / Locality',
                    hint: 'e.g. Sukhsanatantala',
                    icon: Icons.location_city_outlined,
                    textCapitalization: TextCapitalization.words,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          controller: _city,
                          label: 'City',
                          hint: 'e.g. Chandannagar',
                          icon: Icons.location_on_outlined,
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacing12),
                      Expanded(
                        child: _field(
                          controller: _pincode,
                          label: 'Pincode',
                          hint: '712136',
                          icon: Icons.markunread_mailbox_outlined,
                          required: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'Required';
                            if (t.length != 6) return 'Enter 6 digits';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  _field(
                    controller: _landmark,
                    label: 'Landmark',
                    hint: 'e.g. Near Rani Ghat',
                    icon: Icons.flag_outlined,
                    textCapitalization: TextCapitalization.sentences,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),

            // ── Contact & instructions ────────────────────────────────────
            _SectionCard(
              icon: Icons.contact_phone_outlined,
              title: 'Contact & Instructions',
              child: Column(
                children: [
                  _field(
                    controller: _contact,
                    label: 'Contact Number',
                    hint: '10-digit mobile number',
                    icon: Icons.phone_outlined,
                    required: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Required';
                      if (t.length != 10) {
                        return 'Enter a valid 10-digit number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),

            // ── Save as ───────────────────────────────────────────────────
            _SectionCard(
              icon: Icons.bookmark_outline_rounded,
              title: 'Save As',
              child: Column(
                children: [
                  _LabelSelector(
                    selected: _label,
                    onChanged: (v) => setState(() => _label = v),
                  ),
                  const SizedBox(height: AppSizes.spacing12),
                  _DefaultToggle(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spacing24),

            _SaveButton(
              isEditing: widget.isEditing,
              isSaving: _isSaving,
              onTap: _save,
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    bool isLast = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSizes.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label, required: required),
          const SizedBox(height: AppSizes.spacing6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            textInputAction:
                maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
            style: const TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
            validator: validator ??
                (required
                    ? (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null
                    : null),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: AppTypography.fontSize13,
                color: AppColors.textTertiary,
                fontFamily: 'Lato',
              ),
              prefixIcon: Icon(icon,
                  size: AppSizes.icon20, color: AppColors.textSecondary),
              filled: true,
              fillColor: const Color(0xFFF6F8F6),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing12, vertical: AppSizes.spacing12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
                borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: AppSizes.borderMedium),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
                borderSide: const BorderSide(color: AppColors.errorColor),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius12),
                borderSide: const BorderSide(
                    color: AppColors.errorColor, width: AppSizes.borderMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: Icon(icon,
                      size: AppSizes.icon18, color: AppColors.primaryGreen),
                ),
                const SizedBox(width: AppSizes.spacing8),
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
            const SizedBox(height: AppSizes.spacing16),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Location picker tile ─────────────────────────────────────────────────────

class _LocationPickerTile extends StatelessWidget {
  final bool hasLocation;
  final String addressLabel;
  final double? latitude;
  final double? longitude;
  final bool hasError;
  final VoidCallback onTap;

  const _LocationPickerTile({
    required this.hasLocation,
    required this.addressLabel,
    required this.latitude,
    required this.longitude,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.errorColor
        : hasLocation
            ? AppColors.primaryGreen.withValues(alpha: 0.5)
            : AppColors.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            decoration: BoxDecoration(
              color: hasLocation
                  ? AppColors.primaryGreen.withValues(alpha: 0.05)
                  : const Color(0xFFF6F8F6),
              borderRadius: BorderRadius.circular(AppSizes.radius12),
              border: Border.all(
                color: borderColor,
                width: hasError || hasLocation
                    ? AppSizes.borderMedium
                    : AppSizes.borderThin,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasLocation
                        ? Icons.location_on_rounded
                        : Icons.add_location_alt_outlined,
                    size: AppSizes.icon20,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLocation
                            ? 'Location pinned'
                            : 'Select location on map',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasLocation
                            ? (addressLabel.isNotEmpty
                                ? addressLabel
                                : 'Lat ${latitude!.toStringAsFixed(5)}, Lng ${longitude!.toStringAsFixed(5)}')
                            : 'Tap to pin your exact delivery point',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.spacing8),
                Icon(
                  hasLocation ? Icons.edit_location_alt_outlined : Icons.chevron_right,
                  color: AppColors.primaryGreen,
                  size: AppSizes.icon20,
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSizes.spacing6),
          const Text(
            'Location is required',
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              color: AppColors.errorColor,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Field label ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: AppTypography.fontSize13,
          fontWeight: AppTypography.semiBold,
          color: AppColors.textPrimary,
          fontFamily: 'Lato',
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.errorColor),
                ),
              ]
            : null,
      ),
    );
  }
}

// ─── Label selector (Home / Work / Other) ────────────────────────────────────

class _LabelSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _LabelSelector({required this.selected, required this.onChanged});

  static const _options = [
    ('home', 'Home', Icons.home_rounded),
    ('work', 'Work', Icons.work_rounded),
    ('other', 'Other', Icons.place_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (value, label, icon) in _options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
                decoration: BoxDecoration(
                  color: selected == value
                      ? AppColors.primaryGreen.withValues(alpha: 0.10)
                      : const Color(0xFFF6F8F6),
                  borderRadius: BorderRadius.circular(AppSizes.radius12),
                  border: Border.all(
                    color: selected == value
                        ? AppColors.primaryGreen
                        : AppColors.borderColor,
                    width: selected == value
                        ? AppSizes.borderMedium
                        : AppSizes.borderThin,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon,
                        size: AppSizes.icon20,
                        color: selected == value
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary),
                    const SizedBox(height: AppSizes.spacing4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        fontWeight: selected == value
                            ? AppTypography.bold
                            : AppTypography.medium,
                        color: selected == value
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (value != 'other') const SizedBox(width: AppSizes.spacing12),
        ],
      ],
    );
  }
}

// ─── Default toggle ──────────────────────────────────────────────────────────

class _DefaultToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DefaultToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing12, vertical: AppSizes.spacing4),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded,
              size: AppSizes.icon20, color: AppColors.primaryGreen),
          const SizedBox(width: AppSizes.spacing12),
          const Expanded(
            child: Text(
              'Set as default address',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.semiBold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }
}

// ─── Save button ─────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onTap;

  const _SaveButton({
    required this.isEditing,
    required this.isSaving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        onPressed: isSaving ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor:
              AppColors.primaryGreen.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius12),
          ),
        ),
        child: isSaving
            ? const SizedBox(
                width: AppSizes.icon20,
                height: AppSizes.icon20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Text(
                isEditing ? 'Update Address' : 'Save Address',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.bold,
                  color: Colors.white,
                  fontFamily: 'Lato',
                ),
              ),
      ),
    );
  }
}
