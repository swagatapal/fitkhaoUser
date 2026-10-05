import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';
import '../providers/session_provider.dart';
import '../router/route_names.dart';

/// Gates account-based actions behind sign-in.
///
/// Browsing the catalogue is open to everyone; anything that touches an account
/// — cart, checkout, subscriptions, saved addresses, orders — routes through
/// here. Signed-in users run the action straight away; guests get a sheet
/// explaining what sign-in unlocks and a way into the phone flow.
class AuthGate {
  AuthGate._();

  /// Runs [action] when signed in, otherwise prompts the guest to sign in.
  ///
  /// [reason] completes the sentence "Sign in to …", e.g. 'add items to your
  /// cart'. Returns true when [action] ran.
  static Future<bool> run(
    BuildContext context,
    WidgetRef ref, {
    required String reason,
    required VoidCallback action,
  }) async {
    if (ref.read(isSignedInProvider)) {
      action();
      return true;
    }

    await promptSignIn(context, reason: reason, ref: ref);

    // The auth flow pops back to this screen rather than replacing the stack,
    // so the caller is still mounted and the pending action can simply run —
    // the user ends up where they were heading before being interrupted.
    if (!context.mounted || !ref.read(isSignedInProvider)) return false;
    action();
    return true;
  }

  /// Shows the guest sign-in sheet and sends the user to the phone screen when
  /// they accept. Safe to call directly when there is no action to defer.
  static Future<void> promptSignIn(
    BuildContext context, {
    required String reason,
    WidgetRef? ref,
  }) async {
    final wantsSignIn = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SignInPromptSheet(reason: reason),
    );

    if (wantsSignIn != true || !context.mounted) return;

    // Tells the auth screens to pop back here on success instead of doing
    // `go(home)`, which would destroy the stack this screen sits in.
    ref?.read(authReturnPendingProvider.notifier).state = true;
    try {
      await context.push(RouteNames.phoneAuth);
    } finally {
      ref?.read(authReturnPendingProvider.notifier).state = false;
    }
  }

  /// Pops every auth screen pushed by [promptSignIn], returning the user to
  /// the screen they were on. Called by the auth screens on success.
  ///
  /// Routes are identified by the `name` set on their pages, so this stops at
  /// the first non-auth route regardless of how many auth steps were shown
  /// (phone → OTP, plus the name step for a new account).
  static const Set<String> authRouteNames = {
    RouteNames.phoneAuth,
    RouteNames.otpVerification,
    RouteNames.nameInput,
  };

  static void popBackToOrigin(BuildContext context) {
    Navigator.of(context).popUntil((route) {
      final name = route.settings.name;
      return name == null || !authRouteNames.contains(name);
    });
  }
}

class _SignInPromptSheet extends StatelessWidget {
  const _SignInPromptSheet({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spacing20,
            AppSizes.spacing12,
            AppSizes.spacing20,
            AppSizes.spacing20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSizes.spacing24),
              Container(
                padding: const EdgeInsets.all(AppSizes.spacing16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    size: AppSizes.icon32, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: AppSizes.spacing16),
              const Text(
                'Sign in to continue',
                style: TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
              Text(
                'You need an account to $reason. Browsing our menu stays free '
                'either way.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing24),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radius8),
                    ),
                  ),
                  child: const Text(
                    'Login / Sign up',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize16,
                      fontWeight: AppTypography.bold,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Keep browsing',
                  style: TextStyle(
                    fontSize: AppTypography.fontSize14,
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.textSecondary,
                    fontFamily: 'Lato',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
