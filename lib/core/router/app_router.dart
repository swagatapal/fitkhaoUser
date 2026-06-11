import 'package:fitkhao_user/features/notification/presentation/notification_screen.dart';
import 'package:fitkhao_user/features/splash/screens/onboarding_screen.dart';
import 'package:fitkhao_user/features/delivery/presentation/screens/subscription_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/policy/presentation/screens/policy_screen.dart';
import '../../features/profile/presentation/screens/profile_history_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/auth/screens/phone_auth_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/name_input_screen.dart';
import '../../features/auth/screens/address_input_screen.dart';
import '../../features/auth/screens/map_picker_screen.dart';
import '../../features/auth/screens/bmi_analysis_screen.dart';
import '../../features/auth/screens/health_score_screen.dart';
import '../../features/profile/presentation/screens/detailed_health_info_screen.dart';
import '../../features/delivery/presentation/screens/delivery_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/preferences_saved_screen.dart';
import '../services/analytics_service.dart';
import 'route_names.dart';

/// Application router configuration using GoRouter
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    observers: [AnalyticsService.observer],
    debugLogDiagnostics: true,
    routes: [
      // Splash route
      GoRoute(
        path: RouteNames.splash,
        name: RouteNames.splash,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),

      // Splash route
      GoRoute(
        path: RouteNames.onboarding,
        name: RouteNames.onboarding,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),

      // Auth routes
      GoRoute(
        path: RouteNames.phoneAuth,
        name: RouteNames.phoneAuth,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const PhoneAuthScreen(),
        ),
      ),

      GoRoute(
        path: RouteNames.otpVerification,
        name: RouteNames.otpVerification,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const OtpVerificationScreen(),
        ),
      ),

      GoRoute(
        path: RouteNames.nameInput,
        name: RouteNames.nameInput,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const NameInputScreen(),
        ),
      ),

      // GoRoute(
      //   path: RouteNames.addressInput,
      //   name: RouteNames.addressInput,
      //   pageBuilder: (context, state) => MaterialPage(
      //     key: state.pageKey,
      //     child: const AddressInputScreen(),
      //   ),
      // ),

      GoRoute(
        path: RouteNames.mapPicker,
        name: RouteNames.mapPicker,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const MapPickerScreen(),
        ),
      ),

      // GoRoute(
      //   path: RouteNames.bmiAnalysis,
      //   name: RouteNames.bmiAnalysis,
      //   pageBuilder: (context, state) => MaterialPage(
      //     key: state.pageKey,
      //     child: const BmiAnalysisScreen(),
      //   ),
      // ),

      // GoRoute(
      //   path: RouteNames.healthScore,
      //   name: RouteNames.healthScore,
      //   pageBuilder: (context, state) {
      //     final healthData = state.extra as Map<String, dynamic>;
      //     return MaterialPage(
      //       key: state.pageKey,
      //       child: HealthScoreScreen(
      //         healthScore: healthData['healthScore'] as int,
      //         scoreLevel: healthData['scoreLevel'] as String,
      //       ),
      //     );
      //   },
      // ),

      GoRoute(
        path: RouteNames.detailedHealthInfo,
        name: RouteNames.detailedHealthInfo,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const DetailedHealthInfoScreen(),
        ),
      ),

      GoRoute(
        path: RouteNames.editPersonalProfile,
        name: RouteNames.editPersonalProfile,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const EditProfileScreen(),
        ),
      ),

      GoRoute(
        path: RouteNames.preferencesSaved,
        name: RouteNames.preferencesSaved,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const PreferencesSavedScreen(),
        ),
      ),

      // Home route — the menu/delivery screen (drawer-based navigation)
      GoRoute(
        path: RouteNames.home,
        name: RouteNames.home,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const DeliveryScreen(),
        ),
      ),

      // Order history — reachable from the drawer and FCM order events
      GoRoute(
        path: RouteNames.orderHistory,
        name: RouteNames.orderHistory,
        pageBuilder: (context, state) {
          final initialTab = state.extra is HistoryTab
              ? state.extra as HistoryTab
              : HistoryTab.upcoming;
          return MaterialPage(
            key: state.pageKey,
            child: HistoryScreen(initialTab: initialTab),
          );
        },
      ),
      GoRoute(
        path: RouteNames.notificationScreen,
        name: RouteNames.notificationScreen,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const NotificationScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.subscriptionPlans,
        name: RouteNames.subscriptionPlans,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const SubscriptionPlanScreen(),
        ),
      ),

      GoRoute(
        path: RouteNames.profileHistory,
        name: RouteNames.profileHistory,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const ProfileHistoryScreen(),
        ),
      ),

      GoRoute(
        path: RouteNames.policy,
        name: RouteNames.policy,
        pageBuilder: (context, state) {
          final initialTab = state.extra as int? ?? 0;
          return MaterialPage(
            key: state.pageKey,
            child: PolicyScreen(initialTab: initialTab),
          );
        },
      ),
    ],

    // Error page
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Page not found: ${state.uri}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(RouteNames.phoneAuth),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
