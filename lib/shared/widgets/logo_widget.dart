import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/responsive_utils.dart';

class LogoWidget extends StatelessWidget {
  final double? width;
  final double? height;

  const LogoWidget({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: height ?? context.logoSize,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if image not found - show fitkhao text
            return Text(
              'fitkhao',
              style: context.getResponsiveTextStyle(
                fontSize: context.responsiveFontSize(AppTypography.fontSize4XL),
                fontWeight: AppTypography.bold,
                color: AppColors.logoLightGreen,
              ),
            );
          },
        ),
        RichText(
          text: TextSpan(
            text: 'fit',
            style: context.getResponsiveTextStyle(
              fontSize: context.responsiveFontSize(AppTypography.fontSize2XL),
              fontWeight: AppTypography.light,
              color: AppColors.textSecondary,
              decoration: TextDecoration.underline,
            ),
            children: <TextSpan>[
              TextSpan(
                text: 'Khao',
                style: context.getResponsiveTextStyle(
                  fontSize: context.responsiveFontSize(AppTypography.fontSize2XL),
                  fontWeight: AppTypography.bold,
                  color: AppColors.logoGreen,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
