import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/responsive_utils.dart';

class PreferencesSavedScreen extends ConsumerStatefulWidget {

  const PreferencesSavedScreen({ super.key});

  @override
  ConsumerState<PreferencesSavedScreen> createState() =>
      _PreferencesSavedScreenState();
}

class _PreferencesSavedScreenState
    extends ConsumerState<PreferencesSavedScreen> {
  @override
  void initState() {
    super.initState();
    // Auto navigate to home after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        context.go(RouteNames.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing24 = context.responsiveSpacing(24.0);
    final spacing32 = context.responsiveSpacing(32.0);
    final spacing48 = context.responsiveSpacing(48.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background blurred image (placeholder)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryGreen.withValues(alpha: 0.1),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),

          // Success card at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(spacing48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(context.responsiveSpacing(32.0)),
                  topRight: Radius.circular(context.responsiveSpacing(32.0)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: AppSizes.opacity10),
                    blurRadius: AppSizes.shadowBlur20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                 Image.asset("assets/images/buttonshit_logo.png", height: AppSizes.logoHeight,width: AppSizes.logoWidth,),
                  SizedBox(height: spacing24),

                  // "Yay!" title
                  Text(
                    AppStrings.yay,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(36.0),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  SizedBox(height: spacing24),

                  // Success message
                  Text(
                    AppStrings.preferencesSavedTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(20.0),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: spacing32),

                  // Call message
                  Text(
                    AppStrings.expectCallSoon,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(16.0),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: spacing24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
