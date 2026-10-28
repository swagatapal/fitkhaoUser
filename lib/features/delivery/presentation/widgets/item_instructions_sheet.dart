import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/cart_item.dart';

/// Max length of one item's note, sent as `items[].specialInstructions`.
const int kItemInstructionMaxLength = 150;

/// Opens the per-item cooking-instructions sheet shown before an order is
/// placed. Each cart item gets an optional note (e.g. "Extra spicy, no onion").
///
/// Returns the notes keyed by dish id — blank notes are left out — when the
/// user taps Place Order, or `null` when they close the sheet (no order should
/// be placed). [initial] pre-fills notes typed on a previous attempt.
Future<Map<String, String>?> showItemInstructionsSheet(
  BuildContext context, {
  required List<CartItem> cartItems,
  Map<String, String> initial = const {},
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ItemInstructionsSheet(
      cartItems: cartItems,
      initial: initial,
    ),
  );
}

class _ItemInstructionsSheet extends StatefulWidget {
  const _ItemInstructionsSheet({
    required this.cartItems,
    required this.initial,
  });

  final List<CartItem> cartItems;
  final Map<String, String> initial;

  @override
  State<_ItemInstructionsSheet> createState() => _ItemInstructionsSheetState();
}

class _ItemInstructionsSheetState extends State<_ItemInstructionsSheet> {
  /// One controller per dish id.
  late final Map<String, TextEditingController> _controllers = {
    for (final c in widget.cartItems)
      c.menuItem.id: TextEditingController(text: widget.initial[c.menuItem.id]),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final notes = <String, String>{};
    _controllers.forEach((dishId, controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) notes[dishId] = text;
    });
    Navigator.of(context).pop(notes);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      // Lifts the sheet above the keyboard while a note is typed.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Handle + header ──
                const SizedBox(height: AppSizes.spacing12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.spacing20,
                    AppSizes.spacing12,
                    AppSizes.spacing8,
                    AppSizes.spacing4,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cooking instructions',
                          style: TextStyle(
                            fontSize: AppTypography.fontSize18,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.spacing20),
                  child: Text(
                    'Optional — add a note for any dish, e.g. extra spicy or no onion.',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize13,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing12),

                // ── One note field per cart item ──
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacing20),
                    itemCount: widget.cartItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.spacing12),
                    itemBuilder: (_, i) {
                      final item = widget.cartItems[i];
                      return _ItemNoteField(
                        cartItem: item,
                        controller: _controllers[item.menuItem.id]!,
                        isLast: i == widget.cartItems.length - 1,
                        onSubmitLast: _submit,
                      );
                    },
                  ),
                ),

                // ── Place order ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.spacing20,
                    AppSizes.spacing16,
                    AppSizes.spacing20,
                    AppSizes.spacing16,
                  ),
                  child: SizedBox(
                    height: AppSizes.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radius8),
                        ),
                      ),
                      child: const Text(
                        'Place Order',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize16,
                          fontWeight: AppTypography.semiBold,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemNoteField extends StatelessWidget {
  const _ItemNoteField({
    required this.cartItem,
    required this.controller,
    required this.isLast,
    required this.onSubmitLast,
  });

  final CartItem cartItem;
  final TextEditingController controller;
  final bool isLast;
  final VoidCallback onSubmitLast;

  @override
  Widget build(BuildContext context) {
    final item = cartItem.menuItem;
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSizes.radius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                child: Image.network(
                  item.imageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    child: const Icon(Icons.restaurant,
                        size: AppSizes.icon20, color: AppColors.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Text(
                  '${cartItem.quantity} × ${item.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          TextField(
            controller: controller,
            maxLength: kItemInstructionMaxLength,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            textInputAction:
                isLast ? TextInputAction.done : TextInputAction.next,
            onSubmitted: isLast ? (_) => onSubmitLast() : null,
            style: const TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              hintText: 'e.g. Extra spicy, no onion',
              hintStyle: const TextStyle(
                fontSize: AppTypography.fontSize13,
                color: AppColors.textTertiary,
                fontFamily: 'Lato',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing12,
                vertical: AppSizes.spacing10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                borderSide: const BorderSide(
                    color: AppColors.primaryGreen, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
