import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/cart_item.dart';
import '../../models/menu_item.dart';
import '../../providers/cart_provider.dart';
import 'checkout_screen.dart';

/// Dark status-bar icons (time, battery, signal) so the system bar stays
/// visible over this screen's light/white header.
const SystemUiOverlayStyle _kLightScreenOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark, // Android
  statusBarBrightness: Brightness.light, // iOS
);

/// Server-backed cart screen. Lists the user's saved items, lets them adjust
/// quantities / remove lines, and proceed straight to checkout.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh the authoritative cart on entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartProvider.notifier).loadCart();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Lato')),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider);
    final status = ref.watch(cartStatusProvider);

    // Surface mutation/load failures transiently.
    ref.listen<CartStatus>(cartStatusProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        _showError(next.error!);
      }
    });

    final isFirstLoad = status.isLoading && items.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _kLightScreenOverlay,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _Header(itemCount: items.fold(0, (s, c) => s + c.quantity)),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primaryGreen,
                  onRefresh: () => ref.read(cartProvider.notifier).loadCart(),
                  child: _buildBody(isFirstLoad, status, items),
                ),
              ),
              if (items.isNotEmpty) _CheckoutBar(isBusy: status.isMutating),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      bool isFirstLoad, CartStatus status, List<CartItem> items) {
    if (isFirstLoad) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSizes.screenPaddingHorizontal),
        children: List.generate(4, (_) => const _CartCardSkeleton()),
      );
    }

    if (status.isError && items.isEmpty) {
      return _ErrorState(
        message: status.error ?? 'Could not load your cart.',
        onRetry: () => ref.read(cartProvider.notifier).loadCart(),
      );
    }

    if (items.isEmpty) {
      return _EmptyState(onBrowse: () =>  Navigator.of(context).popUntil((route) => route.isFirst));
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPaddingHorizontal),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacing12),
      itemBuilder: (_, i) => _CartLineCard(
        key: ValueKey(items[i].menuItem.id),
        item: items[i],
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int itemCount;
  const _Header({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p20,
        vertical: AppSizes.spacing12,
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
              child: const Icon(Icons.arrow_back,
                  color: AppColors.textWhite, size: AppSizes.icon24),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Cart',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize20,
                    fontWeight: AppTypography.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Lato',
                  ),
                ),
                Text(
                  itemCount > 0
                      ? '$itemCount ${itemCount == 1 ? AppStrings.item : AppStrings.items} in your cart'
                      : 'Your saved items',
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.shopping_cart_outlined,
              color: AppColors.primaryGreen, size: AppSizes.icon24),
        ],
      ),
    );
  }
}

// ─── Cart line card (scoped to its own quantity) ─────────────────────────────

class _CartLineCard extends ConsumerWidget {
  final CartItem item;
  const _CartLineCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = item.menuItem;
    // Rebuild only this card when THIS line's quantity changes.
    final qty = ref.watch(
      cartProvider.select((items) {
        for (final c in items) {
          if (c.menuItem.id == menu.id) return c.quantity;
        }
        return 0;
      }),
    );
    if (qty == 0) return const SizedBox.shrink();

    final lineTotal = (menu.price * qty).toInt();

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: AppSizes.shadowBlur10,
            offset: const Offset(0, AppSizes.spacing2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radius8),
            child: CachedNetworkImage(
              imageUrl: menu.imageUrl,
              width: AppSizes.icon80,
              height: AppSizes.icon80,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: AppSizes.icon80,
                height: AppSizes.icon80,
                color: Colors.grey.withValues(alpha: 0.12),
              ),
              errorWidget: (_, __, ___) => Container(
                width: AppSizes.icon80,
                height: AppSizes.icon80,
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                child: const Icon(Icons.restaurant,
                    size: AppSizes.icon32, color: AppColors.primaryGreen),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        menu.name,
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
                    _VegDot(isVeg: menu.isVeg),
                  ],
                ),
                if (menu.calories > 0) ...[
                  const SizedBox(height: AppSizes.spacing2),
                  Text(
                    '${menu.calories} ${AppStrings.kcal}',
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.spacing8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹$lineTotal',
                      style: const TextStyle(
                        fontSize: AppTypography.fontSize16,
                        fontWeight: AppTypography.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Lato',
                      ),
                    ),
                    _Stepper(item: menu, qty: qty),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VegDot extends StatelessWidget {
  final bool isVeg;
  const _VegDot({required this.isVeg});

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? const Color(0xFF388E3C) : const Color(0xFFD32F2F);
    return Container(
      width: AppSizes.spacing12,
      height: AppSizes.spacing12,
      margin: const EdgeInsets.only(top: AppSizes.spacing2, left: AppSizes.spacing6),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: AppSizes.borderNormal),
      ),
      child: Center(
        child: Container(
          width: AppSizes.spacing6,
          height: AppSizes.spacing6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

// ─── Quantity stepper ────────────────────────────────────────────────────────

class _Stepper extends ConsumerWidget {
  final MenuItem item;
  final int qty;
  const _Stepper({required this.item, required this.qty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final isLast = qty <= 1;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radius6),
        border: Border.all(
            color: AppColors.primaryGreen, width: AppSizes.borderThin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(
            isLast ? Icons.delete_outline_rounded : Icons.remove,
            () => notifier.updateQuantity(item.id, qty - 1),
            color: isLast ? AppColors.errorColor : AppColors.primaryGreen,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.bold,
                color: AppColors.primaryGreen,
                fontFamily: 'Lato',
              ),
            ),
          ),
          _btn(Icons.add, () => notifier.addItem(item)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap,
      {Color color = AppColors.primaryGreen}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ─── Checkout bar ────────────────────────────────────────────────────────────

class _CheckoutBar extends ConsumerWidget {
  final bool isBusy;
  const _CheckoutBar({required this.isBusy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalItems = ref.watch(cartTotalItemsProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing12,
        AppSizes.spacing16,
        AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: AppSizes.shadowBlur20,
            offset: const Offset(0, -AppSizes.spacing4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$totalItems ${totalItems == 1 ? AppStrings.item : AppStrings.items}',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
              Text(
                '₹${totalPrice.toInt()}',
                style: const TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.spacing16),
          Expanded(
            child: SizedBox(
              height: AppSizes.buttonHeight,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isBusy) ...[
                      const SizedBox(
                        width: AppSizes.icon16,
                        height: AppSizes.icon16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacing8),
                    ],
                    const Text(
                      AppStrings.proceedToCheckout,
                      style: TextStyle(
                        fontSize: AppTypography.fontSize14,
                        fontWeight: AppTypography.semiBold,
                        color: Colors.white,
                        fontFamily: 'Lato',
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing4),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: AppSizes.icon18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / error / skeleton states ─────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyState({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSizes.spacing24),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.remove_shopping_cart_outlined,
                size: AppSizes.icon48, color: AppColors.primaryGreen),
          ),
        ),
        const SizedBox(height: AppSizes.spacing20),
        const Text(
          'Your cart is empty',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        const SizedBox(height: AppSizes.spacing8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.spacing32),
          child: Text(
            'Browse the menu and add dishes you love — they’ll show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spacing24),
        Center(
          child: ElevatedButton.icon(
            onPressed: onBrowse,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing24,
                vertical: AppSizes.spacing12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
            ),
            icon: const Icon(Icons.restaurant_menu_rounded,
                color: Colors.white, size: AppSizes.icon20),
            label: const Text(
              'Browse Menu',
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
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.16),
        const Icon(Icons.error_outline_rounded,
            size: AppSizes.icon48, color: AppColors.textTertiary),
        const SizedBox(height: AppSizes.spacing12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTypography.fontSize14,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spacing20),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing24,
                vertical: AppSizes.spacing12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: AppSizes.icon20),
            label: const Text(
              'Retry',
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                fontWeight: AppTypography.semiBold,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CartCardSkeleton extends StatelessWidget {
  const _CartCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacing12),
      height: AppSizes.icon80 + AppSizes.spacing24,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
    );
  }
}
