import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/menu_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/nutrition_provider.dart';

class FoodDetailPopup extends ConsumerStatefulWidget {
  final MenuItem menuItem;

  const FoodDetailPopup({
    super.key,
    required this.menuItem,
  });

  @override
  ConsumerState<FoodDetailPopup> createState() => _FoodDetailPopupState();
}

class _FoodDetailPopupState extends ConsumerState<FoodDetailPopup> {
  bool _isChecking = false;

  /// Check protein consumption before adding to cart
  Future<void> _handleAddToCart() async {
    final authState = ref.read(authProvider);

    // Only check if target protein is set in profile
    if (authState.targetProtein != null && authState.targetProtein! > 0) {
      setState(() {
        _isChecking = true;
      });

      try {
        // Get today's date in yyyy-MM-dd format
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

        // Fetch today's nutrition summary
        await ref.read(nutritionProvider.notifier).getDailyNutritionSummary(date: today);

        final nutritionState = ref.read(nutritionProvider);

        if (nutritionState.totals != null) {
          final currentProtein = nutritionState.totals!.protein;
          final itemProtein = double.tryParse(widget.menuItem.protein.replaceAll('g', '').trim()) ?? 0.0;
          final totalProtein = currentProtein + itemProtein;
          final targetProtein = authState.targetProtein!;

          debugPrint('[FoodDetailPopup] Current protein: $currentProtein, Item protein: $itemProtein, Target: $targetProtein');

          // Check if adding this item exceeds protein target
          if (totalProtein > targetProtein) {
            setState(() {
              _isChecking = false;
            });

            // Show alert dialog
            if (mounted) {
              _showProteinExceededAlert(
                currentProtein: currentProtein,
                itemProtein: itemProtein,
                totalProtein: totalProtein,
                targetProtein: targetProtein,
              );
            }
            return;
          }
        }

        setState(() {
          _isChecking = false;
        });

        // Protein check passed, add to cart
        if (mounted) {
          ref.read(cartProvider.notifier).addItem(widget.menuItem);
          Navigator.of(context).pop();
        }
      } catch (e) {
        debugPrint('[FoodDetailPopup] Error checking nutrition: $e');
        setState(() {
          _isChecking = false;
        });

        // If API fails, still allow add to cart (graceful degradation)
        if (mounted) {
          ref.read(cartProvider.notifier).addItem(widget.menuItem);
          Navigator.of(context).pop();
        }
      }
    } else {
      // No target protein set, add to cart directly
      ref.read(cartProvider.notifier).addItem(widget.menuItem);
      Navigator.of(context).pop();
    }
  }

  /// Show alert when protein target is exceeded
  void _showProteinExceededAlert({
    required double currentProtein,
    required double itemProtein,
    required double totalProtein,
    required double targetProtein,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.orange,
                size: AppSizes.icon24,
              ),
            ),
            const SizedBox(width: AppSizes.spacing12),
            const Expanded(
              child: Text(
                'Protein Limit Exceeded',
                style: TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adding this item will exceed your daily protein target.',
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  _buildProteinRow('Current Consumption', '${currentProtein.toStringAsFixed(1)}g'),
                  const SizedBox(height: AppSizes.spacing8),
                  _buildProteinRow('Item Protein', '+${itemProtein.toStringAsFixed(1)}g', isHighlight: true),
                  const Divider(height: AppSizes.spacing16),
                  _buildProteinRow('Total', '${totalProtein.toStringAsFixed(1)}g', isBold: true),
                  const SizedBox(height: AppSizes.spacing8),
                  _buildProteinRow('Your Target', '${targetProtein.toStringAsFixed(1)}g', isTarget: true),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: AppSizes.icon20,
                  ),
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Text(
                      'You cannot proceed with adding this item to your cart.',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize12,
                        color: Colors.orange.shade800,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
              ),
              child: const Text(
                'Understood',
                style: TextStyle(
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
    );
  }

  Widget _buildProteinRow(String label, String value, {bool isHighlight = false, bool isBold = false, bool isTarget = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.fontSize13,
            fontWeight: isBold ? AppTypography.semiBold : AppTypography.regular,
            color: isTarget ? AppColors.primaryGreen : AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: isBold ? AppTypography.bold : (isHighlight ? AppTypography.semiBold : AppTypography.medium),
            color: isTarget ? AppColors.primaryGreen : (isHighlight ? Colors.orange : AppColors.textPrimary),
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
            // Food Image with Close Button
            Stack(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppSizes.radius8),
                      topRight: Radius.circular(AppSizes.radius8),
                    ),
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppSizes.radius8),
                      topRight: Radius.circular(AppSizes.radius8),
                    ),
                    child: Image.network(
                      widget.menuItem.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.restaurant,
                            size: AppSizes.icon80,
                            color: AppColors.primaryGreen,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Close button at top right
                Positioned(
                  top: AppSizes.spacing8,
                  right: AppSizes.spacing8,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.spacing8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        size: AppSizes.icon20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(AppSizes.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food Name
                  Text(
                    widget.menuItem.name,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize20,
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  //const SizedBox(height: AppSizes.spacing8),

                  // Calories and Rating
                  Row(
                    children: [
                      Text(
                        '${AppStrings.calories} ${widget.menuItem.calories}kcal',
                        style: const TextStyle(
                          fontSize: AppTypography.fontSize14,
                          fontWeight: AppTypography.medium,
                          color: AppColors.textSecondary,
                          fontFamily: 'Lato',
                        ),
                      ),
                      if (widget.menuItem.rating > 0) ...[
                        const SizedBox(width: AppSizes.spacing16),
                        const Icon(
                          Icons.star,
                          size: AppSizes.icon16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: AppSizes.spacing4),
                        Text(
                          '${widget.menuItem.rating.toStringAsFixed(1)}/5',
                          style: const TextStyle(
                            fontSize: AppTypography.fontSize16,
                            fontWeight: AppTypography.semiBold,
                            color: AppColors.textPrimary,
                            fontFamily: 'Lato',
                          ),
                        ),
                      ],
                    ],
                  ),
                  //const SizedBox(height: AppSizes.spacing16),

                  // Description
                  // const Text(
                  //   AppStrings.description,
                  //   style: TextStyle(
                  //     fontSize: AppTypography.fontSize16,
                  //     fontWeight: AppTypography.semiBold,
                  //     color: AppColors.textPrimary,
                  //     fontFamily: 'Lato',
                  //   ),
                  // ),
                  // const SizedBox(height: AppSizes.spacing8),
                  // Text(
                  //   menuItem.description,
                  //   style: const TextStyle(
                  //     fontSize: AppTypography.fontSize14,
                  //     fontWeight: AppTypography.regular,
                  //     color: AppColors.textSecondary,
                  //     fontFamily: 'Lato',
                  //     height: 1.5,
                  //   ),
                  // ),
                  const SizedBox(height: AppSizes.spacing16),

                  // Goal Category
                  if (widget.menuItem.goalCategory.isNotEmpty) ...[
                    const Text(
                      'Goal Category',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing8),
                    Wrap(
                      spacing: AppSizes.spacing8,
                      runSpacing: AppSizes.spacing8,
                      children: widget.menuItem.goalCategory.map((category) {
                        return _buildChip(
                          category.replaceAll('-', ' ').split(' ').map((word) =>
                            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word
                          ).join(' '),
                          AppColors.primaryGreen,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSizes.spacing12),
                  ],

                  // Tags
                  if (widget.menuItem.tags.isNotEmpty) ...[
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing8),
                    Wrap(
                      spacing: AppSizes.spacing8,
                      runSpacing: AppSizes.spacing8,
                      children: widget.menuItem.tags.map((tag) {
                        return _buildChip(tag, AppColors.darkGreen);
                      }).toList(),
                    ),
                    const SizedBox(height: AppSizes.spacing12),
                  ],

                  // Allergens
                  if (widget.menuItem.allergens.isNotEmpty) ...[
                    const Text(
                      'Allergens',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing8),
                    Wrap(
                      spacing: AppSizes.spacing8,
                      runSpacing: AppSizes.spacing8,
                      children: widget.menuItem.allergens.map((allergen) {
                        return _buildChip(allergen, AppColors.errorColor);
                      }).toList(),
                    ),
                    const SizedBox(height: AppSizes.spacing12),
                  ],

                  // Nutritional Information
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNutritionItem(AppStrings.protein, widget.menuItem.protein),
                      _buildNutritionItem(AppStrings.carbs, widget.menuItem.carbs),
                      _buildNutritionItem(AppStrings.fats, widget.menuItem.fats),
                      //_buildNutritionItem(AppStrings.fiber, widget.menuItem.fiber),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spacing12),

                  // Suitability Information
                  if (widget.menuItem.suitability.isNotEmpty) ...[
                    const Text(
                      'Dietary Suitability',
                      style: TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.semiBold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacing8),
                    _buildSuitabilitySection(widget.menuItem.suitability),
                  ],
                ],
              ),
            ),
                  ],
                ),
              ),
            ),

            // Fixed Add to Cart Button at bottom
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppSizes.radius8),
                  bottomRight: Radius.circular(AppSizes.radius8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _handleAddToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shopping_cart,
                              color: Colors.white,
                              size: AppSizes.icon20,
                            ),
                            const SizedBox(width: AppSizes.spacing8),
                            const Text(
                              AppStrings.addToCart,
                              style: TextStyle(
                                fontSize: AppTypography.fontSize16,
                                fontWeight: AppTypography.semiBold,
                                color: Colors.white,
                                fontFamily: 'Lato',
                              ),
                            ),
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

  Widget _buildNutritionItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTypography.fontSize12,
            fontWeight: AppTypography.regular,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing4),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppTypography.fontSize14,
            fontWeight: AppTypography.semiBold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
        border: Border.all(
          color: color,
          width: AppSizes.borderThin,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.fontSize12,
          fontWeight: AppTypography.medium,
          color: color,
          fontFamily: 'Lato',
        ),
      ),
    );
  }

  Widget _buildSuitabilitySection(Map<String, dynamic> suitability) {
    final List<Widget> suitableWidgets = [];
    final List<Widget> notSuitableWidgets = [];

    // General conditions
    if (suitability.containsKey('generalPublic')) {
      final isSuitable = suitability['generalPublic'] == true;
      if (isSuitable) {
        suitableWidgets.add(
          _buildSuitabilityChip(
            'General Public',
            Icons.check_circle,
            Colors.green,
          ),
        );
      } else {
        notSuitableWidgets.add(
          _buildSuitabilityChip(
            'General Public',
            Icons.cancel,
            Colors.red,
          ),
        );
      }
    }

    // Medical conditions
    final medicalConditions = {
      't2dm': 'Type 2 Diabetes',
      'htn': 'Hypertension',
      'cvd': 'Cardiovascular Disease',
      'ckd': 'Chronic Kidney Disease',
    };

    medicalConditions.forEach((key, label) {
      if (suitability.containsKey(key)) {
        final isSuitable = suitability[key] == true;
        if (isSuitable) {
          suitableWidgets.add(
            _buildSuitabilityChip(
              label,
              Icons.check_circle,
              AppColors.primaryGreen,
            ),
          );
        } else {
          notSuitableWidgets.add(
            _buildSuitabilityChip(
              label,
              Icons.cancel,
              Colors.red,
            ),
          );
        }
      }
    });

    // Pregnancy stages
    final pregnancy = suitability['pregnancy'] as Map<String, dynamic>?;
    if (pregnancy != null) {
      final pregnancyStages = {
        'p1': 'Pregnancy Trimester 1',
        'p2': 'Pregnancy Trimester 2',
        'p3': 'Pregnancy Trimester 3',
      };

      pregnancyStages.forEach((key, label) {
        if (pregnancy.containsKey(key)) {
          final isSuitable = pregnancy[key] == true;
          if (isSuitable) {
            suitableWidgets.add(
              _buildSuitabilityChip(
                label,
                Icons.check_circle,
                Colors.purple,
              ),
            );
          } else {
            notSuitableWidgets.add(
              _buildSuitabilityChip(
                label,
                Icons.cancel,
                Colors.red,
              ),
            );
          }
        }
      });
    }

    // Lactation stages
    final lactation = suitability['lactation'] as Map<String, dynamic>?;
    if (lactation != null) {
      final lactationStages = {
        'l1': 'Lactation Stage 1',
        'l2': 'Lactation Stage 2',
      };

      lactationStages.forEach((key, label) {
        if (lactation.containsKey(key)) {
          final isSuitable = lactation[key] == true;
          if (isSuitable) {
            suitableWidgets.add(
              _buildSuitabilityChip(
                label,
                Icons.check_circle,
                Colors.pink,
              ),
            );
          } else {
            notSuitableWidgets.add(
              _buildSuitabilityChip(
                label,
                Icons.cancel,
                Colors.red,
              ),
            );
          }
        }
      });
    }

    // If both lists are empty, return nothing
    if (suitableWidgets.isEmpty && notSuitableWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Suitable section
        if (suitableWidgets.isNotEmpty) ...[
          const Text(
            'Suitable For',
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              fontWeight: AppTypography.semiBold,
              color: AppColors.primaryGreen,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing6),
          Wrap(
            spacing: AppSizes.spacing8,
            runSpacing: AppSizes.spacing8,
            children: suitableWidgets,
          ),
        ],

        // Spacing between sections
        if (suitableWidgets.isNotEmpty && notSuitableWidgets.isNotEmpty)
          const SizedBox(height: AppSizes.spacing12),

        // Not suitable section
        if (notSuitableWidgets.isNotEmpty) ...[
          const Text(
            'Not Suitable For',
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              fontWeight: AppTypography.semiBold,
              color: Colors.red,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing6),
          Wrap(
            spacing: AppSizes.spacing8,
            runSpacing: AppSizes.spacing8,
            children: notSuitableWidgets,
          ),
        ],
      ],
    );
  }

  Widget _buildSuitabilityChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppSizes.icon16,
            color: color,
          ),
          const SizedBox(width: AppSizes.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              fontWeight: AppTypography.medium,
              color: color,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }
}
