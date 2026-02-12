import 'package:fitkhao_user/core/constants/app_colors.dart';
import 'package:fitkhao_user/core/constants/app_sizes.dart';
import 'package:fitkhao_user/core/constants/app_typography.dart';
import 'package:fitkhao_user/core/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
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

  // Animations
  late Animation<double> _backgroundOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textOpacity;

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

    // Text animation (1500-2500ms)
    _textController = AnimationController(
      duration: const Duration(milliseconds: AppSizes.durationSlow),
      vsync: this,
    );

    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
  }

  Future<void> _startAnimationSequence() async {
    // Fetch and print auth token from local storage
    await _fetchAndPrintToken();

    // Start background fade
    await _backgroundController.forward();

    // Start logo animation
    await _logoController.forward();

    // Start text animation
    await _textController.forward();

    // Wait a bit before checking profile
    await Future.delayed(const Duration(milliseconds: AppSizes.durationSlow));

    // Check if user has a valid profile
    final hasValidProfile = await _checkUserProfile();

    // Navigate based on profile status
    if (mounted) {
      if (hasValidProfile) {
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
