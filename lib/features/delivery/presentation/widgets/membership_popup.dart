import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/wallet_balance_model.dart';
import '../screens/subscription_plan_screen.dart';

class MembershipPopup extends StatefulWidget {
  final SubscriptionInfo? subscription;

  const MembershipPopup({super.key, this.subscription});

  @override
  State<MembershipPopup> createState() => _MembershipPopupState();
}

class _MembershipPopupState extends State<MembershipPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _closePopup() async {
    await _controller.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          await _closePopup();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Background overlay
            FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: _closePopup,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              ),
            ),
            // Popup content
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing24,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A7C3E), Color(0xFF6BA84F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.radius12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Background pattern
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.radius24),
                          child: Opacity(
                            opacity: 0.1,
                            child: Image.asset(
                              'assets/images/header_bg.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(AppSizes.spacing24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Close button
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: _closePopup,
                                    child: Container(
                                      padding: const EdgeInsets.all(AppSizes.spacing8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radius8,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: AppSizes.icon24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.spacing16),
                              // Logo/Icon
                              Container(
                                padding: const EdgeInsets.all(AppSizes.spacing16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  'assets/images/buttonshit_logo.png',
                                  height: AppSizes.icon60,
                                  width: AppSizes.icon60,
                                ),
                              ),
                              const SizedBox(height: AppSizes.spacing20),
                              // Title
                              const Text(
                                'FitKhao Plus',
                                style: TextStyle(
                                  fontSize: AppTypography.fontSize32,
                                  fontWeight: AppTypography.bold,
                                  color: Colors.white,
                                  fontFamily: 'Lato',
                                ),
                              ),
                              const SizedBox(height: AppSizes.spacing8),
                              // Subtitle or subscription details
                              if (widget.subscription?.isActive == true) ...[
                                Container(
                                  padding: const EdgeInsets.all(AppSizes.spacing16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Active Plan : ${widget.subscription!.planName}",
                                        style: const TextStyle(
                                          fontSize: AppTypography.fontSize16,
                                          fontWeight: AppTypography.semiBold,
                                          color: Colors.white,
                                          fontFamily: 'Lato',
                                        ),
                                      ),
                                      Text(
                                        '( ${widget.subscription!.remainingDays} days remaining )',
                                        style: const TextStyle(
                                          fontSize: AppTypography.fontSize14,
                                          fontWeight: AppTypography.medium,
                                          color: Colors.white,
                                          fontFamily: 'Lato',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else
                                const Text(
                                  'Unlock Premium Benefits',
                                  style: TextStyle(
                                    fontSize: AppTypography.fontSize16,
                                    fontWeight: AppTypography.medium,
                                    color: Colors.white,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                              const SizedBox(height: AppSizes.spacing24),
                              // Subscribe/Subscribed button
                              if (widget.subscription?.isActive == true)
                                SizedBox(
                                  width: double.infinity,
                                  height: AppSizes.buttonHeight,
                                  child: ElevatedButton(
                                    onPressed: ()async{
                                      final navigator = Navigator.of(context);
                                      await _closePopup();
                                      if (mounted) {
                                        navigator.push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                            const SubscriptionPlanScreen(),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.primaryGreen,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radius4,
                                        ),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: const Text(
                                      'Subscribed',
                                      style: TextStyle(
                                        fontSize: AppTypography.fontSize18,
                                        fontWeight: AppTypography.bold,
                                        fontFamily: 'Lato',
                                      ),
                                    ),
                                  ),
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  height: AppSizes.buttonHeight,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final navigator = Navigator.of(context);
                                      await _closePopup();
                                      if (mounted) {
                                        navigator.push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const SubscriptionPlanScreen(),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.primaryGreen,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radius4,
                                        ),
                                      ),
                                      elevation: 4,
                                    ),
                                    child: const Text(
                                      'Subscribe Now',
                                      style: TextStyle(
                                        fontSize: AppTypography.fontSize18,
                                        fontWeight: AppTypography.bold,
                                        fontFamily: 'Lato',
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: AppSizes.spacing12),
                              // Close button
                              TextButton(
                                onPressed: _closePopup,
                                child: Text(
                                  widget.subscription?.isActive == true ? 'Close' : 'Maybe Later',
                                  style: const TextStyle(
                                    fontSize: AppTypography.fontSize14,
                                    fontWeight: AppTypography.medium,
                                    color: Colors.white,
                                    fontFamily: 'Lato',
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

}
