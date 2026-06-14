import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../delivery/providers/selected_address_provider.dart';
import '../../models/delivery_address_model.dart';
import '../../providers/delivery_address_provider.dart';
import 'address_form_screen.dart';

/// Dark status-bar icons so the system bar stays visible over the white header.
const SystemUiOverlayStyle _kHeaderOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark, // Android
  statusBarBrightness: Brightness.light, // iOS
);

/// Lists the user's saved delivery addresses with full CRUD entry points.
class AddressListScreen extends ConsumerStatefulWidget {
  const AddressListScreen({super.key});

  @override
  ConsumerState<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends ConsumerState<AddressListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addressProvider.notifier).loadAddresses();
    });
  }

  void _openForm({DeliveryAddressModel? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddressFormScreen(existing: existing),
      ),
    );
  }

  Future<void> _confirmDelete(DeliveryAddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius12)),
        title: const Text(
          'Delete Address',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this address? This action cannot be undone.',
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: AppTypography.semiBold,
                fontFamily: 'Lato',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8)),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: AppTypography.semiBold,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final result =
        await ref.read(addressProvider.notifier).deleteAddress(address.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? 'Address deleted'
            : (result.message.isNotEmpty
                ? result.message
                : 'Failed to delete address')),
        backgroundColor:
            result.success ? AppColors.primaryGreen : AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _setDefault(DeliveryAddressModel address) async {
    final result =
        await ref.read(addressProvider.notifier).setDefault(address);
    if (!mounted) return;
    if (result.success) {
      // Marking an address default is an explicit intent to deliver there —
      // make it the app-wide active selection so the delivery/checkout header
      // updates immediately (the list has already refreshed at this point).
      final list = ref.read(addressProvider).addresses;
      final updated = list.firstWhere(
        (a) => a.id == address.id,
        orElse: () => address.copyWith(isDefault: true),
      );
      ref.read(selectedDeliveryAddressProvider.notifier).select(updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message.isNotEmpty
              ? result.message
              : 'Failed to update default address'),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                  'Saved Addresses',
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
    final state = ref.watch(addressProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _kHeaderOverlay,
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSizes.spacing16),
        child: SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () => _openForm(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8)),
            ),
            label: const Text(
              'Add New Address',
              style: TextStyle(
                fontSize: AppTypography.fontSize16,
                fontWeight: AppTypography.bold,
                color: Colors.white,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildBody(AddressState state) {
    if (state.isLoading && state.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (state.error != null && state.isEmpty) {
      return _ErrorView(
        message: state.error!,
        onRetry: () => ref.read(addressProvider.notifier).loadAddresses(),
      );
    }

    if (state.isEmpty) {
      return const _EmptyView();
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () => ref.read(addressProvider.notifier).loadAddresses(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.spacing16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.addresses.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
        itemBuilder: (_, i) {
          final address = state.addresses[i];
          return _AddressCard(
            address: address,
            onEdit: () => _openForm(existing: address),
            onDelete: () => _confirmDelete(address),
            onSetDefault:
                address.isDefault ? null : () => _setDefault(address),
          );
        },
      ),
    );
  }
}

// ─── Address card ────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final DeliveryAddressModel address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  ({IconData icon, String text}) get _labelMeta {
    switch (address.label.toLowerCase()) {
      case 'work':
        return (icon: Icons.work_rounded, text: 'Work');
      case 'other':
        return (icon: Icons.place_rounded, text: 'Other');
      case 'home':
      default:
        return (icon: Icons.home_rounded, text: 'Home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _labelMeta;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(
          color: address.isDefault
              ? AppColors.primaryGreen.withValues(alpha: 0.4)
              : AppColors.borderColor,
          width: address.isDefault
              ? AppSizes.borderMedium
              : AppSizes.borderThin,
        ),
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
                  padding: const EdgeInsets.all(AppSizes.spacing8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: Icon(meta.icon,
                      size: AppSizes.icon20, color: AppColors.primaryGreen),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Text(
                  meta.text,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize15,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                const SizedBox(width: AppSizes.spacing8),
                if (address.isDefault) const _DefaultBadge(),
                const Spacer(),
                _IconAction(
                  icon: Icons.edit_outlined,
                  color: AppColors.textSecondary,
                  onTap: onEdit,
                ),
                _IconAction(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.errorColor,
                  onTap: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              address.formattedAddress,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textPrimary,
                height: 1.4,
                fontFamily: 'Lato',
              ),
            ),
            if (address.landmark.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing6),
              _MetaRow(
                  icon: Icons.flag_outlined, text: 'Near ${address.landmark}'),
            ],
            if (address.contactNumber.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing6),
              _MetaRow(
                  icon: Icons.phone_outlined, text: address.contactNumber),
            ],
            if (address.deliveryInstructions.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing6),
              _MetaRow(
                  icon: Icons.notes_outlined,
                  text: address.deliveryInstructions),
            ],
            if (onSetDefault != null) ...[
              const Divider(height: AppSizes.spacing24),
              GestureDetector(
                onTap: onSetDefault,
                behavior: HitTestBehavior.opaque,
                child: const Row(
                  children: [
                    Icon(Icons.star_outline_rounded,
                        size: AppSizes.icon18, color: AppColors.primaryGreen),
                    SizedBox(width: AppSizes.spacing6),
                    Text(
                      'Set as default',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize13,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.primaryGreen,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing8, vertical: AppSizes.spacing2),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
      child: const Text(
        'DEFAULT',
        style: TextStyle(
          fontSize: AppTypography.fontSize10,
          fontWeight: AppTypography.bold,
          color: Colors.white,
          letterSpacing: 0.5,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizes.icon14, color: AppColors.textTertiary),
        const SizedBox(width: AppSizes.spacing6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: AppTypography.fontSize12,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconAction(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius8),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing6),
        child: Icon(icon, size: AppSizes.icon20, color: color),
      ),
    );
  }
}

// ─── Empty / error states ────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing20),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_outlined,
                  size: AppSizes.icon48, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: AppSizes.spacing20),
            const Text(
              'No saved addresses',
              style: TextStyle(
                fontSize: AppTypography.fontSize16,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            const Text(
              'Add a delivery address to get your\nmeals delivered right to your door.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize13,
                color: AppColors.textSecondary,
                height: 1.5,
                fontFamily: 'Lato',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: AppSizes.icon48, color: AppColors.errorColor),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius8)),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.primaryGreen,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
