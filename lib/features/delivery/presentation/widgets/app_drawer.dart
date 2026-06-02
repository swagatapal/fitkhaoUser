import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../notification/presentation/notification_screen.dart';
import '../../../policy/presentation/screens/policy_screen.dart';
import '../../../profile/presentation/screens/detailed_health_info_screen.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import '../screens/subscription_plan_screen.dart';

/// Side navigation drawer attached to [DeliveryScreen].
///
/// Replaces the old bottom navigation bar. Each entry pushes its destination
/// screen onto the navigator (so the user gets a natural back button), after
/// first closing the drawer.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  // ── Navigation helpers ──────────────────────────────────────────────────

  /// Close the drawer, then push [screen] onto the navigator.
  ///
  /// The page navigator is captured *before* closing the drawer because the
  /// Scaffold drawer is not a navigator route — closing it must go through
  /// [ScaffoldState.closeDrawer], and the captured navigator stays valid.
  void _open(BuildContext context, Widget screen) {
    final navigator = Navigator.of(context);
    Scaffold.of(context).closeDrawer();
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  // ── Contact us ──────────────────────────────────────────────────────────

  /// Support contact details. Update these to the real values.
  static const String _supportEmail = 'support@fitkhao.com';
  static const String _supportPhone = '+919999999999';

  void _showContactUs(BuildContext context) {
    Scaffold.of(context).closeDrawer();
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
                label: _supportEmail,
                onTap: () => _launchUri(
                  sheetContext,
                  Uri(scheme: 'mailto', path: _supportEmail),
                ),
              ),
              const SizedBox(height: AppSizes.spacing12),
              _ContactTile(
                icon: Icons.phone_outlined,
                label: _supportPhone,
                onTap: () => _launchUri(
                  sheetContext,
                  Uri(scheme: 'tel', path: _supportPhone),
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUri(BuildContext context, Uri uri) async {
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

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          _buildHeader(context, authState),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
              children: [
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: 'Profile Details',
                  onTap: () => _open(context, const DetailedHealthInfoScreen()),
                ),
                _DrawerItem(
                  icon: Icons.edit_outlined,
                  label: 'Edit Profile',
                  onTap: () => _open(context, const EditProfileScreen()),
                ),
                _DrawerItem(
                  icon: Icons.schedule_outlined,
                  label: 'Upcoming Orders',
                  onTap: () => _open(
                    context,
                    const HistoryScreen(initialTab: HistoryTab.upcoming),
                  ),
                ),
                _DrawerItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Delivered Orders',
                  onTap: () => _open(
                    context,
                    const HistoryScreen(initialTab: HistoryTab.delivered),
                  ),
                ),
                _DrawerItem(
                  icon: Icons.card_membership_outlined,
                  label: 'Subscription Details',
                  onTap: () => _open(context, const SubscriptionPlanScreen()),
                ),
                _DrawerItem(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  onTap: () => _open(context, const NotificationScreen()),
                ),
                _DrawerItem(
                  icon: Icons.policy_outlined,
                  label: 'Terms & Conditions',
                  onTap: () => _open(context, const PolicyScreen()),
                ),
                _DrawerItem(
                  icon: Icons.support_agent_outlined,
                  label: 'Contact Us',
                  onTap: () => _showContactUs(context),
                ),
                const Divider(height: AppSizes.spacing24, indent: 16, endIndent: 16),
                _DrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  iconColor: AppColors.errorColor,
                  labelColor: AppColors.errorColor,
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic authState) {
    final name = (authState.name as String).isNotEmpty
        ? authState.name as String
        : 'FitKhao User';
    final imgUrl = authState.imgUrl as String?;
    final phone = authState.phoneNumber as String? ?? '';
    final countryCode = authState.countryCode as String? ?? '';
    final hasImage = imgUrl != null && imgUrl.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSizes.spacing20,
        MediaQuery.of(context).padding.top + AppSizes.spacing20,
        AppSizes.spacing20,
        AppSizes.spacing20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A7C3E), Color(0xFF6BA84F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            backgroundImage: hasImage ? NetworkImage(imgUrl) : null,
            child: hasImage
                ? null
                : Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                      fontFamily: 'Lato',
                    ),
                  ),
          ),
          const SizedBox(height: AppSizes.spacing12),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppTypography.fontSize18,
              fontWeight: AppTypography.bold,
              color: Colors.white,
              fontFamily: 'Lato',
            ),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacing2),
            Text(
              '$countryCode $phone'.trim(),
              style: TextStyle(
                fontSize: AppTypography.fontSize13,
                color: Colors.white.withValues(alpha: 0.85),
                fontFamily: 'Lato',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing20,
        vertical: AppSizes.spacing16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu,
              size: AppSizes.icon16, color: AppColors.textTertiary),
          const SizedBox(width: AppSizes.spacing6),
          Text(
            'FitKhao',
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textTertiary,
              fontFamily: 'Lato',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single drawer row ─────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      horizontalTitleGap: AppSizes.spacing12,
      leading: Icon(
        icon,
        size: AppSizes.icon24,
        color: iconColor ?? AppColors.primaryGreen,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.fontSize14,
          fontWeight: AppTypography.medium,
          color: labelColor ?? AppColors.textPrimary,
          fontFamily: 'Lato',
        ),
      ),
    );
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
