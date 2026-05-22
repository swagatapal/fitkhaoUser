import 'package:fitkhao_user/core/constants/app_colors.dart';
import 'package:fitkhao_user/core/constants/app_sizes.dart';
import 'package:fitkhao_user/core/constants/app_typography.dart';
import 'package:fitkhao_user/core/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
import '../../../core/services/firebase_notification_service.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _subtitleController;

  // Animations
  late Animation<double> _backgroundOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textOpacity;
  late Animation<Offset> _subtitleSlideAnimation;
  late Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
  }

  /// Fetch and print auth token from local storage
  Future<void> _fetchAndPrintToken() async {
    try {
      final localStorage = await ref.read(localStorageProvider.future);
      final authToken = localStorage.getAuthToken();

      debugPrint('========================================');
      debugPrint('AUTH TOKEN FROM LOCAL STORAGE:');
      debugPrint('========================================');
      if (authToken != null && authToken.isNotEmpty) {
        debugPrint('Token: $authToken');
      } else {
        debugPrint('Token: No token found');
      }
      debugPrint('========================================');
    } catch (e) {
      debugPrint('Error fetching auth token: $e');
    }
  }

  /// Check if user has a valid profile
  /// Returns true if profile exists and is valid, false otherwise
  Future<bool> _checkUserProfile() async {
    try {
      final localStorage = await ref.read(localStorageProvider.future);
      final authToken = localStorage.getAuthToken();

      // If no token, user needs to login
      if (authToken == null || authToken.isEmpty) {
        debugPrint('[SplashScreen] No auth token found');
        return false;
      }

      // Try to load profile
      final authNotifier = ref.read(authProvider.notifier);
      final success = await authNotifier.loadProfile();

      if (success) {
        final authState = ref.read(authProvider);
        // Check if profile has required data (name exists)
        final hasProfile = authState.name.isNotEmpty;

        debugPrint('[SplashScreen] Profile check result: $hasProfile');
        return hasProfile;
      }

      debugPrint('[SplashScreen] Profile load failed');
      return false;
    } catch (e) {
      debugPrint('[SplashScreen] Error checking profile: $e');
      return false;
    }
  }

  void _setupAnimations() {
    // Background fade animation (0-500ms)
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: AppSizes.durationMedium),
      vsync: this,
    );

    _backgroundOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeIn),
    );

    // Logo animation (500-1500ms)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: AppSizes.durationSlow),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Title text animation (1500-2500ms)
    _textController = AnimationController(
      duration: const Duration(milliseconds: AppSizes.durationSlow),
      vsync: this,
    );

    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    // Subtitle animation — starts after title completes
    _subtitleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _subtitleSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _subtitleController,
            curve: Curves.easeOutCubic,
          ),
        );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeIn),
    );
  }

  Future<void> _startAnimationSequence() async {
    // Fetch and print auth token from local storage
    await _fetchAndPrintToken();

    // Start background fade
    await _backgroundController.forward();

    // Start logo animation
    await _logoController.forward();

    // Start title animation, then subtitle after a brief pause
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 120));
    await _subtitleController.forward();

    // Wait a bit before checking profile
    await Future.delayed(const Duration(milliseconds: 400));

    // Check if user has a valid profile
    final hasValidProfile = await _checkUserProfile();
    final notificationService = FirebaseNotificationService.getInstance();

    // Navigate based on profile status
    if (mounted) {
      if (hasValidProfile) {
        if (notificationService.hasNotificationNavigationInProgress) {
          debugPrint(
            '[SplashScreen] Notification launch detected, skipping default home navigation',
          );
          notificationService.flushPendingNavigationIfPossible();
          return;
        }

        // User has valid profile - go to home
        debugPrint('[SplashScreen] Navigating to home');
        context.go(RouteNames.home);
      } else {
        // User needs to login/complete profile - go to onboarding
        debugPrint('[SplashScreen] Navigating to onboarding');
        context.go(RouteNames.onboarding);
      }
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Color(0xFF5D9E40),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _backgroundController,
          _logoController,
          _textController,
          _subtitleController,
        ]),
        builder: (context, child) {
          return Stack(
            children: [
              // Animated background with pattern
              Opacity(
                opacity: _backgroundOpacity.value,
                child: Container(
                  width: double.infinity,
                  height: context.responsiveFontSize(
                                381,
                              ),
                  decoration: const BoxDecoration(
                    // gradient: LinearGradient(
                    //   colors: [Color(0xFF5D9E40), Color(0xFF4A7D33)],
                    //   begin: Alignment.topLeft,
                    //   end: Alignment.bottomRight,
                    // ),
                  ),
                  child: Image.asset(
                    "assets/images/splash.png",
                    width: size.width,
                    height: context.responsiveFontSize(
                                381,
                              ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Center content with logo and text
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated logo
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Image.asset(
                          "assets/images/logo_1.png",
                          width: AppSizes.logoWidth,
                          height: AppSizes.logoHeight,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.spacing24),

                    // Animated fitkhao text
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: RichText(
                          text: TextSpan(
                            text: 'fit',
                            style: context.getResponsiveTextStyle(
                              fontSize: context.responsiveFontSize(
                                AppTypography.fontSize40,
                              ),
                              fontWeight: AppTypography.light,
                              color: AppColors.textWhite,
                              decoration: TextDecoration.underline,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: 'Khao',
                                style: context.getResponsiveTextStyle(
                                  fontSize: context.responsiveFontSize(
                                    AppTypography.fontSize40,
                                  ),
                                  fontWeight: AppTypography.bold,
                                  color: AppColors.textWhite,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.spacing12),
                    SlideTransition(
                      position: _subtitleSlideAnimation,
                      child: Opacity(
                        opacity: _subtitleOpacity.value,
                        child: RichText(
                          text: TextSpan(
                            text: 'fit khao,',
                            style: context.getResponsiveTextStyle(
                              fontSize: context.responsiveFontSize(
                                AppTypography.fontSize32,
                              ),
                              fontWeight: AppTypography.light,
                              color: AppColors.textWhite,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: ' fit raho!',
                                style: context.getResponsiveTextStyle(
                                  fontSize: context.responsiveFontSize(
                                    AppTypography.fontSize32,
                                  ),
                                  fontWeight: AppTypography.bold,
                                  color: AppColors.textWhite,
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
            ],
          );
        },
      ),
    );
  }
}
