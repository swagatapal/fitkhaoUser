import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/providers/auth_provider.dart';

/// Shared navigation / contact / logout behaviour for the profile menu.
///
/// Used by both the slide-in drawer ([AppMenuContent]) and the full-screen
/// menu ([ProfileMenuScreen]) so the two surfaces stay behaviourally identical
/// while presenting different UIs.
class ProfileMenuActions {
  ProfileMenuActions._();

  /// Support contact details. Update these to the real values.
  static const String supportEmail = 'support@fitkhao.com';
  static const String supportPhone = '9635139595';

  /// Push [screen], closing the drawer first when hosted inside one.
  static void open(
    BuildContext context,
    Widget screen, {
    bool insideDrawer = false,
  }) {
    final navigator = Navigator.of(context);
    if (insideDrawer) {
      // A Scaffold drawer is not a navigator route — close it explicitly.
      Scaffold.of(context).closeDrawer();
    }
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  // ── Contact us ──────────────────────────────────────────────────────────

  static void showContactUs(BuildContext context, {bool insideDrawer = false}) {
    if (insideDrawer) Scaffold.of(context).closeDrawer();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacing20),
              const Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing4),
              const Text(
                'We are here to help. Reach out to us anytime.',
                style: TextStyle(
                  fontSize: AppTypography.fontSize13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Lato',
                ),
              ),
              const SizedBox(height: AppSizes.spacing20),
              _ContactTile(
                icon: Icons.email_outlined,
                label: supportEmail,
                onTap: () => _launchUri(
                  sheetContext,
                  Uri(scheme: 'mailto', path: supportEmail),
                ),
              ),
              const SizedBox(height: AppSizes.spacing12),
              _ContactTile(
                icon: Icons.phone_outlined,
                label: supportPhone,
                onTap: () => _launchUri(
                  sheetContext,
                  Uri(scheme: 'tel', path: supportPhone),
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _launchUri(BuildContext context, Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No app available to handle this action')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
      }
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  static Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius8),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontSize: AppTypography.fontSize18,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            fontSize: AppTypography.fontSize14,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: AppTypography.semiBold,
                fontFamily: 'Lato',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radius4),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontWeight: AppTypography.semiBold,
                fontFamily: 'Lato',
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted) return;

    // Show a blocking loader while the logout request runs.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );

    final success = await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;

    Navigator.of(context).pop(); // dismiss the loader

    if (success) {
      // Replaces the whole stack, so the drawer / menu screen are discarded.
      context.go(RouteNames.phoneAuth);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to logout. Please try again.'),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─── Contact-us row ────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius8),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSizes.radius8),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSizes.icon20, color: AppColors.primaryGreen),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.semiBold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: AppSizes.icon20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
