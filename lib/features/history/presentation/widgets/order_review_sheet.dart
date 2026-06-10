import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/order_history_model.dart';
import '../../providers/order_history_provider.dart';

/// Bottom sheet that lets the user rate every dish and add overall feedback.
/// Only shown when `order.orderStatus == 'delivered' && !order.isReviewed`.
class OrderReviewSheet extends ConsumerStatefulWidget {
  final OrderHistory order;

  const OrderReviewSheet({super.key, required this.order});

  @override
  ConsumerState<OrderReviewSheet> createState() => _OrderReviewSheetState();
}

class _OrderReviewSheetState extends ConsumerState<OrderReviewSheet> {
  late final Map<String, int> _ratings;
  late final Map<String, TextEditingController> _reviewControllers;
  late final TextEditingController _feedbackController;
  bool _attemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    _ratings = {for (final item in widget.order.items) item.dishId: 0};
    _reviewControllers = {
      for (final item in widget.order.items)
        item.dishId: TextEditingController(),
    };
    _feedbackController = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in _reviewControllers.values) {
      c.dispose();
    }
    _feedbackController.dispose();
    super.dispose();
  }

  bool get _allRated => _ratings.values.every((r) => r > 0);

  Future<void> _submit() async {
    setState(() => _attemptedSubmit = true);
    if (!_allRated) return;

    final items = widget.order.items
        .map((item) => DishRatingInput(
              dishId: item.dishId,
              rating: _ratings[item.dishId]!,
              review: _reviewControllers[item.dishId]?.text.trim(),
            ))
        .toList();

    final feedback = _feedbackController.text.trim();

    try {
      await ref.read(orderHistoryProvider.notifier).submitReview(
            orderId: widget.order.id,
            items: items,
            feedback: feedback.isEmpty ? null : feedback,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.errorColor,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(
      orderHistoryProvider
          .select((s) => s.isReviewSubmitting(widget.order.id)),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _DragHandle(),
              _SheetHeader(
                orderNumber: widget.order.orderNumber,
                onClose: () => Navigator.of(context).pop(),
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p20,
                    vertical: AppSizes.spacing16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rate each dish',
                        style: TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.textSecondary,
                          fontFamily: AppTypography.fontFamily,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacing12),
                      ...widget.order.items.asMap().entries.map((e) {
                        final idx = e.key;
                        final item = e.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: idx < widget.order.items.length - 1
                                ? AppSizes.spacing12
                                : 0,
                          ),
                          child: _ItemRatingCard(
                            item: item,
                            rating: _ratings[item.dishId] ?? 0,
                            controller: _reviewControllers[item.dishId]!,
                            showError: _attemptedSubmit &&
                                (_ratings[item.dishId] ?? 0) == 0,
                            onRatingChanged: (r) =>
                                setState(() => _ratings[item.dishId] = r),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSizes.spacing20),
                      _FeedbackSection(controller: _feedbackController),
                      const SizedBox(height: AppSizes.spacing24),
                      _SubmitButton(
                        isSubmitting: isSubmitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSizes.spacing16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String orderNumber;
  final VoidCallback onClose;

  const _SheetHeader({required this.orderNumber, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rate Your Order',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize18,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Order #$orderNumber',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize13,
                    color: AppColors.textSecondary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ItemRatingCard extends StatelessWidget {
  final OrderHistoryItem item;
  final int rating;
  final TextEditingController controller;
  final bool showError;
  final ValueChanged<int> onRatingChanged;

  const _ItemRatingCard({
    required this.item,
    required this.rating,
    required this.controller,
    required this.showError,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border: Border.all(
          color: showError ? AppColors.errorColor : AppColors.borderColor,
          width: showError ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radius6),
                child: _DishThumbnail(url: item.dishImage),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: AppTypography.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StarRatingBar(rating: rating, onChanged: onRatingChanged),
                  ],
                ),
              ),
            ],
          ),
          if (showError) ...[
            const SizedBox(height: 6),
            const Text(
              'Please rate this item',
              style: TextStyle(
                fontSize: AppTypography.fontSize12,
                color: AppColors.errorColor,
                fontFamily: AppTypography.fontFamily,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.spacing12),
          TextField(
            controller: controller,
            maxLines: 2,
            maxLength: 200,
            style: const TextStyle(
              fontSize: AppTypography.fontSize13,
              color: AppColors.textPrimary,
              fontFamily: AppTypography.fontFamily,
            ),
            decoration: InputDecoration(
              hintText: 'Write a review (optional)…',
              hintStyle: const TextStyle(
                fontSize: AppTypography.fontSize13,
                color: AppColors.textSecondary,
                fontFamily: AppTypography.fontFamily,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius6),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius6),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius6),
                borderSide:
                    const BorderSide(color: AppColors.primaryGreen, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
              counterStyle: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  final TextEditingController controller;

  const _FeedbackSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overall Experience',
          style: TextStyle(
            fontSize: AppTypography.fontSize15,
            fontWeight: AppTypography.semiBold,
            color: AppColors.textPrimary,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tell us about your delivery experience (optional)',
          style: TextStyle(
            fontSize: AppTypography.fontSize13,
            color: AppColors.textSecondary,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
        const SizedBox(height: AppSizes.spacing10),
        TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 300,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textPrimary,
            fontFamily: AppTypography.fontFamily,
          ),
          decoration: InputDecoration(
            hintText: 'Share your feedback…',
            hintStyle: const TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: AppTypography.fontFamily,
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
              borderSide:
                  const BorderSide(color: AppColors.primaryGreen, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
            counterStyle: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onPressed;

  const _SubmitButton({required this.isSubmitting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          elevation: 0,
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Submit Review',
                style: TextStyle(
                  fontSize: AppTypography.fontSize16,
                  fontWeight: AppTypography.semiBold,
                  color: Colors.white,
                  fontFamily: AppTypography.fontFamily,
                ),
              ),
      ),
    );
  }
}

class _StarRatingBar extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _StarRatingBar({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final value = i + 1;
        return GestureDetector(
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              value <= rating
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: value <= rating
                  ? const Color(0xFFFFC107)
                  : AppColors.borderColor,
              size: 30,
            ),
          ),
        );
      }),
    );
  }
}

class _DishThumbnail extends StatelessWidget {
  final String? url;

  const _DishThumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: 52,
        height: 52,
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        child: const Center(
          child: Icon(Icons.restaurant, color: AppColors.primaryGreen, size: 24),
        ),
      );
}
