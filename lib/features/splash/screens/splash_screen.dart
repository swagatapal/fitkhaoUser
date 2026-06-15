import 'package:fitkhao_user/core/constants/app_colors.dart';
import 'package:fitkhao_user/core/constants/app_sizes.dart';
import 'package:fitkhao_user/core/constants/app_typography.dart';
import 'package:fitkhao_user/core/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/router/route_names.dart';
import '../../../core/services/firebase_notification_service.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../policy/models/app_version_model.dart';

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
    await _fetchAndPrintToken();

    await _backgroundController.forward();
    await _logoController.forward();
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 120));
    await _subtitleController.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    // Version check — returns false when a force-update dialog is shown
    // (in that case we must NOT navigate; the user has to update the app).
    final canContinue = await _checkAndHandleAppVersion();
    if (!canContinue || !mounted) return;

    final hasValidProfile = await _checkUserProfile();
    final notificationService = FirebaseNotificationService.getInstance();

    if (!mounted) return;
    if (hasValidProfile) {
      if (notificationService.hasNotificationNavigationInProgress) {
        debugPrint(
          '[SplashScreen] Notification launch detected, skipping default home navigation',
        );
        notificationService.flushPendingNavigationIfPossible();
        return;
      }
      debugPrint('[SplashScreen] Navigating to home');
      context.go(RouteNames.home);
    } else {
      debugPrint('[SplashScreen] Navigating to onboarding');
      context.go(RouteNames.onboarding);
    }
  }

  // ── App version check ───────────────────────────────────────────────────────

  /// Returns true  → proceed normally (up-to-date or optional update handled).
  /// Returns false → force-update dialog shown; do NOT navigate.
  Future<bool> _checkAndHandleAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = "3.0.0";
      //final currentVersion = packageInfo.version;

      final repo = ref.read(appContentRepositoryProvider);
      final versionInfo = await repo.checkAppVersion(
        currentVersion: currentVersion,
      );

      if (versionInfo == null || !mounted) return true;

      print("latest version is : ${versionInfo.latestVersion}");
      final updateAvailable = _isUpdateAvailable(
        current: currentVersion,
        latest: versionInfo.latestVersion,
      );

      if (!updateAvailable) return true;

      if (versionInfo.isForceUpdate) {
        // Show blocking dialog — do NOT await; we never want to proceed past it.
        _showForceUpdateDialog(versionInfo);
        return false;
      } else {
        // Show dismissible dialog and continue after user responds.
        await _showOptionalUpdateDialog(versionInfo);
        return true;
      }
    } catch (e) {
      debugPrint('[SplashScreen] Version check error (proceeding): $e');
      return true;
    }
  }

  /// Returns true when [latest] is strictly greater than [current].
  /// Parses semantic-version triples (major.minor.patch).
  bool _isUpdateAvailable({required String current, required String latest}) {
    try {
      final c = current.split('.').map(int.parse).toList();
      final l = latest.split('.').map(int.parse).toList();
      for (var i = 0; i < 3; i++) {
        final cv = i < c.length ? c[i] : 0;
        final lv = i < l.length ? l[i] : 0;
        if (lv > cv) return true;
        if (cv > lv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('[SplashScreen] Could not launch update URL: $url');
    }
  }

  /// Non-dismissible dialog. User MUST tap "Update Now" — app will not proceed.
  void _showForceUpdateDialog(AppVersionModel info) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radius12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            AppSizes.spacing24,
            AppSizes.spacing24,
            AppSizes.spacing24,
            AppSizes.spacing8,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: AppColors.primaryGreen,
                  size: AppSizes.icon48,
                ),
              ),
              const SizedBox(height: AppSizes.spacing16),
              const Text(
                'Update Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.fontSize20,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
              const Text(
                'A new version of FitKhao is required to continue. Please update the app to keep using all features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
              if (info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: AppSizes.spacing12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.spacing12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSizes.radius8),
                  ),
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize13,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.spacing20),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: () => _openUpdateUrl(info.updateUrl),
                  icon: const Icon(Icons.open_in_new, size: AppSizes.icon20),
                  label: const Text(
                    'Update Now',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize16,
                      fontWeight: AppTypography.bold,
                      fontFamily: 'Lato',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacing12),
            ],
          ),
        ),
      ),
    );
  }

  /// Dismissible dialog. User may skip and continue using the current version.
  Future<void> _showOptionalUpdateDialog(AppVersionModel info) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          AppSizes.spacing24,
          AppSizes.spacing24,
          AppSizes.spacing24,
          AppSizes.spacing8,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.spacing16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: AppColors.primaryGreen,
                size: AppSizes.icon48,
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            const Text(
              'Update Available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize20,
                fontWeight: AppTypography.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            const Text(
              'A new version of FitKhao is available. Update now for the latest features and improvements.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                color: AppColors.textSecondary,
                fontFamily: 'Lato',
              ),
            ),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spacing12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.spacing12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                ),
                child: Text(
                  info.releaseNotes,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSize13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.spacing20),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSizes.spacing16,
          0,
          AppSizes.spacing16,
          AppSizes.spacing16,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.spacing12,
                    ),
                  ),
                  child: const Text(
                    'Later',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.semiBold,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _openUpdateUrl(info.updateUrl);
                  },
                  icon: const Icon(Icons.open_in_new, size: AppSizes.icon20),
                  label: const Text(
                    'Update',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.bold,
                      fontFamily: 'Lato',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.spacing12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
