import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// The app's back button — one size everywhere: a 40×40 tap target holding a
/// 24 px arrow, matching the Saved Addresses / Coupons / Plans headers.
///
/// • default   → dark-green rounded square, for white app bars.
/// • [onColor] → translucent white circle, for green / gradient headers.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onTap, this.onColor = false});

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onTap;

  /// Use on a coloured header instead of a white bar.
  final bool onColor;

  /// Outer size of the button.
  static const double size = 40;

  /// Size of the arrow inside it.
  static const double iconSize = AppSizes.icon24;

  @override
  Widget build(BuildContext context) {
    final tap = onTap ?? () => Navigator.of(context).maybePop();
    const icon = Icon(Icons.arrow_back_rounded,
        color: AppColors.textWhite, size: iconSize);

    if (onColor) {
      return Material(
        color: Colors.white.withValues(alpha: 0.2),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: tap,
          child: const SizedBox(width: size, height: size, child: icon),
        ),
      );
    }

    return Material(
      color: AppColors.darkGreen,
      borderRadius: BorderRadius.circular(AppSizes.radius8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        onTap: tap,
        child: const SizedBox(width: size, height: size, child: icon),
      ),
    );
  }
}
