import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/providers.dart';
import '../../../delivery/providers/delivery_slot_list_provider.dart';
import '../../../profile/providers/delivery_address_provider.dart';
import '../../models/order_history_model.dart';

/// Bottom sheet to change a subscription order's delivery slot and/or address
/// (PUT /api/orders/{orderId}/subscription-slot). The server enforces the
/// 6:00 AM IST deadline on the delivery date; its message is surfaced on
/// rejection. Pops `true` after a successful update.
class SubscriptionSlotChangeSheet extends ConsumerStatefulWidget {
  const SubscriptionSlotChangeSheet({super.key, required this.order});

  final OrderHistory order;

  @override
  ConsumerState<SubscriptionSlotChangeSheet> createState() =>
      _SubscriptionSlotChangeSheetState();
}

class _SubscriptionSlotChangeSheetState
    extends ConsumerState<SubscriptionSlotChangeSheet> {
  late String _slotId = widget.order.deliverySlot.id;
  String? _addressId; // null = keep the order's current address
  bool _submitting = false;

  bool get _slotChanged =>
      _slotId.isNotEmpty && _slotId != widget.order.deliverySlot.id;

  bool get _hasChange => _slotChanged || _addressId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(addressProvider).addresses.isEmpty) {
        ref.read(addressProvider.notifier).loadAddresses(silent: true);
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting || !_hasChange) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res =
          await ref.read(orderRepositoryProvider).updateSubscriptionOrderSlot(
                orderId: widget.order.id,
                slotId: _slotChanged ? _slotId : null,
                deliveryAddressId: _addressId,
              );
      if (!mounted) return;
      if (res['success'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
        content: Text((res['message'] as String?)?.isNotEmpty == true
            ? res['message'] as String
            : 'Could not update this delivery.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(deliverySlotListProvider);
    final addresses = ref.watch(addressProvider.select((s) => s.addresses));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Change delivery',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize18,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                        Text(
                          'Order ${widget.order.orderNumber}',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize12,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.9),
                            fontFamily: 'Lato',
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded,
                        size: AppSizes.icon20, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  _deadlineNote(),
                  const SizedBox(height: AppSizes.spacing16),
                  const _Label('Delivery slot'),
                  const SizedBox(height: AppSizes.spacing8),
                  slotsAsync.when(
                    loading: () => const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSizes.spacing16),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryGreen),
                      ),
                    ),
                    error: (_, __) => _retryRow('Could not load slots.',
                        () => ref.invalidate(deliverySlotListProvider)),
                    data: (slots) => Column(
                      children: [
                        for (final s in slots)
                          _OptionTile(
                            title: s.slotName,
                            subtitle: s.timeRange,
                            selected: _slotId == s.id,
                            onTap: _submitting
                                ? null
                                : () => setState(() => _slotId = s.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing16),
                  const _Label('Delivery address'),
                  const SizedBox(height: 2),
                  Text(
                    'Leave unselected to keep the current address.',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize10,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  if (addresses.isEmpty)
                    Text(
                      'No saved addresses found.',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                        fontFamily: 'Lato',
                      ),
                    )
                  else
                    for (final a in addresses)
                      _OptionTile(
                        title: a.label.isEmpty
                            ? 'Address'
                            : '${a.label[0].toUpperCase()}${a.label.substring(1)}',
                        subtitle: a.formattedAddress,
                        selected: _addressId == a.id,
                        onTap: _submitting
                            ? null
                            : () => setState(() =>
                                _addressId = _addressId == a.id ? null : a.id),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: _hasChange && !_submitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.borderColor.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _hasChange
                              ? 'Update delivery'
                              : 'Pick a new slot or address',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize14,
                            fontWeight: AppTypography.bold,
                            fontFamily: 'Lato',
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deadlineNote() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border:
            Border.all(color: const Color(0xFFC66301).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule_rounded,
              size: AppSizes.icon18, color: Color(0xFFC66301)),
          SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Text(
              'Changes are allowed only before 6:00 AM IST on the delivery day.',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                color: Color(0xFF795548),
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _retryRow(String message, VoidCallback onRetry) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            size: AppSizes.icon18, color: AppColors.errorColor),
        const SizedBox(width: AppSizes.spacing8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: AppTypography.fontSize12,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry',
              style:
                  TextStyle(fontFamily: 'Lato', color: AppColors.primaryGreen)),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: AppTypography.fontSize14,
          fontWeight: AppTypography.bold,
          color: AppColors.textPrimary,
          fontFamily: 'Lato',
        ),
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
        padding: const EdgeInsets.all(AppSizes.spacing12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryGreen.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: selected
                ? AppColors.primaryGreen
                : AppColors.borderColor.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: AppSizes.icon20,
              color: selected ? AppColors.primaryGreen : AppColors.textTertiary,
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
