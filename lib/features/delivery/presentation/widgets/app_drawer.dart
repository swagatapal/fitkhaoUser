import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../notification/presentation/notification_screen.dart';
import '../../../policy/presentation/screens/policy_screen.dart';
import '../../../profile/presentation/screens/detailed_health_info_screen.dart';
import '../../../profile/presentation/screens/edit_profile_screen.dart';
import '../../../profile/presentation/screens/profile_menu_actions.dart';
import '../screens/subscription_plan_screen.dart';

/// Side navigation drawer attached to [DeliveryScreen].
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(
      backgroundColor: Colors.white,
      child: AppMenuContent(),
    );
  }
}

/// Drawer body — gradient header, item list and footer.
///
/// Behaviour (navigation / contact / logout) is delegated to
/// [ProfileMenuActions] so the full-screen [ProfileMenuScreen] reuses exactly
/// the same logic.
class AppMenuContent extends ConsumerWidget {
  const AppMenuContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Column(
      children: [
        _buildHeader(context, authState),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
            children: [
              _DrawerItem(
                icon: Icons.person_outline,
                label: 'Profile Details',
                onTap: () => ProfileMenuActions.open(
                    context, const DetailedHealthInfoScreen(),
                    insideDrawer: true),
              ),
              _DrawerItem(
                icon: Icons.edit_outlined,
                label: 'Edit Profile',
                onTap: () => ProfileMenuActions.open(
                    context, const EditProfileScreen(),
                    insideDrawer: true),
              ),
              _DrawerItem(
                icon: Icons.schedule_outlined,
                label: 'Upcoming Orders',
                onTap: () => ProfileMenuActions.open(
                    context, const HistoryScreen(initialTab: HistoryTab.upcoming),
                    insideDrawer: true),
              ),
              _DrawerItem(
                icon: Icons.receipt_long_outlined,
                label: 'Delivered Orders',
                onTap: () => ProfileMenuActions.open(
                    context, const HistoryScreen(initialTab: HistoryTab.delivered),
                    insideDrawer: true),
              ),
              _DrawerItem(
                icon: Icons.card_membership_outlined,
                label: 'Subscription Details',
                onTap: () => ProfileMenuActions.open(
                    context, const SubscriptionPlanScreen(),
                    insideDrawer: true),
              ),
              _DrawerItem(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () => ProfileMenuActions.open(
                    context, const NotificationScreen(),
                    insideDrawer: true),
              ),
              _DrawerItem(
                icon: Icons.policy_outlined,
                label: 'Terms & Conditions',
                onTap: () => ProfileMenuActions.open(
                    context, const PolicyScreen(),
                    insideDrawer: true),
              ),
              _DrawerItem(
                icon: Icons.support_agent_outlined,
                label: 'Contact Us',
                onTap: () =>
                    ProfileMenuActions.showContactUs(context, insideDrawer: true),
              ),
              const Divider(height: AppSizes.spacing24, indent: 16, endIndent: 16),
              _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                iconColor: AppColors.errorColor,
                labelColor: AppColors.errorColor,
                onTap: () => ProfileMenuActions.confirmLogout(context, ref),
              ),
            ],
          ),
        ),
        _buildFooter(),
      ],
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
        MediaQuery.of(context).padding.top + AppSizes.spacing16,
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
