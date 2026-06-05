import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/kitchen_model.dart';
import '../../providers/kitchen_provider.dart';
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
              const _KitchenSelectorSection(),
              const Divider(
                  height: AppSizes.spacing24, indent: 16, endIndent: 16),
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

// ─── Kitchen selector ──────────────────────────────────────────────────────

/// Drawer section that shows the currently selected kitchen and opens a picker.
/// Multiple kitchens may be returned; the first is default-selected upstream.
class _KitchenSelectorSection extends ConsumerWidget {
  const _KitchenSelectorSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchenState = ref.watch(kitchenProvider);
    final selected = kitchenState.selectedKitchen;
    final isOpen = kitchenState.isKitchenOpen != false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing4,
        AppSizes.spacing16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Kitchen',
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              fontWeight: AppTypography.semiBold,
              color: AppColors.textSecondary,
              fontFamily: 'Lato',
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          GestureDetector(
            onTap: kitchenState.isLoading
                ? null
                : () => _openKitchenPicker(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing12,
                vertical: AppSizes.spacing12,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSizes.radius12),
                border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.spacing8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        size: AppSizes.icon20, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  Expanded(
                    child: kitchenState.isLoading && selected == null
                        ? Text(
                            'Loading kitchens…',
                            style: TextStyle(
                              fontSize: AppTypography.fontSize14,
                              color: AppColors.textSecondary,
                              fontFamily: 'Lato',
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected?.name ?? 'No kitchen available',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTypography.fontSize14,
                                  fontWeight: AppTypography.bold,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Lato',
                                ),
                              ),
                              if (selected != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOpen
                                            ? AppColors.primaryGreen
                                            : AppColors.errorColor,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.spacing4),
                                    Text(
                                      isOpen ? 'Open now' : 'Closed',
                                      style: TextStyle(
                                        fontSize: AppTypography.fontSize12,
                                        color: isOpen
                                            ? AppColors.primaryGreen
                                            : AppColors.errorColor,
                                        fontFamily: 'Lato',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                  ),
                  if (kitchenState.kitchens.length > 1)
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openKitchenPicker(BuildContext context, WidgetRef ref) {
    final kitchens = ref.read(kitchenProvider).kitchens;
    if (kitchens.length <= 1) return; // nothing to choose from

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _KitchenPickerSheet(
        onSelect: (kitchen) {
          ref.read(kitchenProvider.notifier).selectKitchen(kitchen);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }
}

/// Bottom sheet listing all active kitchens for selection.
class _KitchenPickerSheet extends ConsumerWidget {
  final ValueChanged<KitchenModel> onSelect;

  const _KitchenPickerSheet({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchenState = ref.watch(kitchenProvider);
    final selectedId = kitchenState.selectedKitchenId;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSizes.spacing12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSizes.spacing20, AppSizes.spacing16,
                AppSizes.spacing20, AppSizes.spacing8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose a Kitchen',
                style: TextStyle(
                  fontSize: AppTypography.fontSize18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Lato',
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
              itemCount: kitchenState.kitchens.length,
              itemBuilder: (_, i) {
                final kitchen = kitchenState.kitchens[i];
                final isSelected = kitchen.id == selectedId;
                return ListTile(
                  onTap: () => onSelect(kitchen),
                  leading: Icon(
                    Icons.storefront_rounded,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary,
                  ),
                  title: Text(
                    kitchen.name,
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: isSelected
                          ? AppTypography.bold
                          : AppTypography.medium,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  subtitle: Text(
                    kitchen.isOpen ? 'Open now' : 'Closed',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: kitchen.isOpen
                          ? AppColors.primaryGreen
                          : AppColors.errorColor,
                      fontFamily: 'Lato',
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: AppColors.primaryGreen)
                      : null,
                );
              },
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
