import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../../../notification/presentation/notification_screen.dart';
import '../../../policy/presentation/screens/policy_screen.dart';
import '../../../delivery/presentation/screens/subscription_plan_screen.dart';
import 'detailed_health_info_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_menu_actions.dart';

/// Full-screen, polished version of the navigation menu.
///
/// Opened by tapping the profile avatar on `DeliveryScreen`. Shares all
/// behaviour with the drawer through [ProfileMenuActions] but presents a
/// richer layout — a gradient hero header plus grouped cards.
class ProfileMenuScreen extends ConsumerWidget {
  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── Sticky profile header ──────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: const Color(0xFF4A7C3E),
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 4,
            shadowColor: Colors.black26,
            automaticallyImplyLeading: false,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: _ProfileFlexibleHeader(authState: authState),
          ),

          // ── Scrollable menu content ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacing16,
                AppSizes.spacing20,
                AppSizes.spacing16,
                AppSizes.spacing8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // ── Account ───────────────────────────────────────────────
                const _SectionLabel('Account'),
                _MenuCard(
                  items: [
                    _MenuEntry(
                      icon: Icons.person_outline_rounded,
                      color: AppColors.primaryGreen,
                      title: 'Profile Details',
                      subtitle: 'Health, body & goals',
                      onTap: () => ProfileMenuActions.open(
                          context, const DetailedHealthInfoScreen()),
                    ),
                    _MenuEntry(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF2E7CF6),
                      title: 'Edit Profile',
                      subtitle: 'Name, address & photo',
                      onTap: () => ProfileMenuActions.open(
                          context, const EditProfileScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing20),

                // ── Orders ────────────────────────────────────────────────
                const _SectionLabel('Orders'),
                _MenuCard(
                  items: [
                    _MenuEntry(
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFFC66301),
                      title: 'Upcoming Orders',
                      subtitle: 'Track active orders',
                      onTap: () => ProfileMenuActions.open(
                        context,
                        const HistoryScreen(initialTab: HistoryTab.upcoming),
                      ),
                    ),
                    _MenuEntry(
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFF20A39E),
                      title: 'Delivered Orders',
                      subtitle: 'Your past orders',
                      onTap: () => ProfileMenuActions.open(
                        context,
                        const HistoryScreen(initialTab: HistoryTab.delivered),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing20),

                // ── Membership & more ─────────────────────────────────────
                const _SectionLabel('Membership & More'),
                _MenuCard(
                  items: [
                    _MenuEntry(
                      icon: Icons.card_membership_outlined,
                      color: const Color(0xFF8B5CF6),
                      title: 'Subscription Details',
                      subtitle: 'Plans & wallet balance',
                      onTap: () => ProfileMenuActions.open(
                          context, const SubscriptionPlanScreen()),
                    ),
                    _MenuEntry(
                      icon: Icons.notifications_none_rounded,
                      color: const Color(0xFFF5A623),
                      title: 'Notifications',
                      subtitle: 'Alerts & updates',
                      onTap: () => ProfileMenuActions.open(
                          context, const NotificationScreen()),
                    ),
                    _MenuEntry(
                      icon: Icons.policy_outlined,
                      color: const Color(0xFF607D8B),
                      title: 'Terms & Conditions',
                      subtitle: 'Policies & privacy',
                      onTap: () => ProfileMenuActions.open(
                          context, const PolicyScreen()),
                    ),
                    _MenuEntry(
                      icon: Icons.support_agent_outlined,
                      color: const Color(0xFF1E9E63),
                      title: 'Contact Us',
                      subtitle: 'We’re here to help',
                      onTap: () => ProfileMenuActions.showContactUs(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacing24),

                // ── Logout ────────────────────────────────────────────────
                _LogoutButton(
                  onTap: () => ProfileMenuActions.confirmLogout(context, ref),
                ),
                const SizedBox(height: AppSizes.spacing20),

                // ── Version footer ────────────────────────────────────────
                Center(
                  child: Text(
                    'FitKhao • v${AppConfigVersion.version}',
                    style: TextStyle(
                      fontSize: AppTypography.fontSize12,
                      fontWeight: AppTypography.medium,
                      color: AppColors.textTertiary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing24),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny constant holder so the footer version is a single source of truth.
class AppConfigVersion {
  static const String version = '1.0.0';
}

// ─── Collapsible sticky header ───────────────────────────────────────────────
//
// Rendered inside [SliverAppBar.flexibleSpace]. Reads the live collapse
// progress from [FlexibleSpaceBarSettings] and cross-fades between:
//   • the expanded hero (large avatar + name + phone, anchored to the bottom)
//   • a compact bar (small avatar + name + phone) that stays pinned at the top.
// The back / edit action buttons remain visible in both states.

class _ProfileFlexibleHeader extends StatelessWidget {
  final dynamic authState;
  const _ProfileFlexibleHeader({required this.authState});

  @override
  Widget build(BuildContext context) {
    final name = (authState.name as String).isNotEmpty
        ? authState.name as String
        : 'FitKhao User';
    final imgUrl = authState.imgUrl as String?;
    final phone = authState.phoneNumber as String? ?? '';
    final countryCode = authState.countryCode as String? ?? '';
    final hasImage = imgUrl != null && imgUrl.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final phoneLabel = '$countryCode $phone'.trim();
    final topInset = MediaQuery.of(context).padding.top;

    // Collapse progress: 0 = fully expanded, 1 = fully collapsed.
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    double t = 0;
    if (settings != null) {
      final delta = settings.maxExtent - settings.minExtent;
      if (delta > 0) {
        t = (1 - (settings.currentExtent - settings.minExtent) / delta)
            .clamp(0.0, 1.0);
      }
    }

    // Cross-fade windows — expanded fades out early, compact fades in late.
    final expandedOpacity = (1 - t * 1.6).clamp(0.0, 1.0);
    final compactOpacity = ((t - 0.55) / 0.45).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A7C3E), Color(0xFF6BA84F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // Decorative translucent circles
          Positioned(top: -30, right: -20, child: _circle(120, 0.08)),
          Positioned(bottom: -25, left: -25, child: _circle(90, 0.06)),

          // Expanded hero — anchored to the bottom, fades out while collapsing.
          Positioned(
            left: AppSizes.spacing20+AppSizes.spacing20+AppSizes.spacing20,
            right: AppSizes.spacing20,
            bottom: AppSizes.spacing20,
            child: Opacity(
              opacity: expandedOpacity,
              child: IgnorePointer(
                ignoring: expandedOpacity < 0.5,
                child: Row(
                  children: [
                    _avatar(hasImage, imgUrl, initial, radius: 36, fontSize: 30),
                    const SizedBox(width: AppSizes.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppTypography.fontSize20,
                              fontWeight: AppTypography.bold,
                              color: Colors.white,
                              fontFamily: 'Lato',
                            ),
                          ),
                          if (phoneLabel.isNotEmpty) ...[
                            const SizedBox(height: AppSizes.spacing4),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: AppSizes.icon14,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: AppSizes.spacing4),
                                Text(
                                  phoneLabel,
                                  style: TextStyle(
                                    fontSize: AppTypography.fontSize13,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontFamily: 'Lato',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top action row (persistent) + compact identity (fades in collapsed).
          Positioned(
            top: topInset + 6,
            left: AppSizes.spacing12,
            right: AppSizes.spacing12,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  _circleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Opacity(
                      opacity: compactOpacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacing12,
                        ),
                        child: Row(
                          children: [
                            _avatar(hasImage, imgUrl, initial,
                                radius: 20, fontSize: 14),
                            const SizedBox(width: AppSizes.spacing8),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                  // if (phoneLabel.isNotEmpty)
                                  //   Text(
                                  //     phoneLabel,
                                  //     maxLines: 1,
                                  //     overflow: TextOverflow.ellipsis,
                                  //     style: TextStyle(
                                  //       fontSize: AppTypography.fontSize10,
                                  //       color:
                                  //           Colors.white.withValues(alpha: 0.85),
                                  //       fontFamily: 'Lato',
                                  //     ),
                                  //   ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // _circleButton(
                  //   icon: Icons.edit_outlined,
                  //   onTap: () => ProfileMenuActions.open(
                  //       context, const EditProfileScreen()),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(
    bool hasImage,
    String? imgUrl,
    String initial, {
    required double radius,
    required double fontSize,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.25),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: hasImage ? NetworkImage(imgUrl!) : null,
        child: hasImage
            ? null
            : Text(
                initial,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                  fontFamily: 'Lato',
                ),
              ),
      ),
    );
  }

  Widget _circle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: AppSizes.icon20),
        ),
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSizes.spacing4,
        bottom: AppSizes.spacing8,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: AppTypography.fontSize12,
          fontWeight: AppTypography.bold,
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontFamily: 'Lato',
        ),
      ),
    );
  }
}

// ─── Grouped card ────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<_MenuEntry> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _MenuTile(entry: items[i]),
            if (i != items.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 64,
                endIndent: 16,
                color: Color(0xFFF0F0F0),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Menu tile ─────────────────────────────────────────────────────────────

class _MenuEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _MenuTile extends StatelessWidget {
  final _MenuEntry entry;
  const _MenuTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing16,
          vertical: AppSizes.spacing12,
        ),
        child: Row(
          children: [
            // Colored soft icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: entry.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radius12),
              ),
              child: Icon(entry.icon, color: entry.color, size: AppSizes.icon20),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: AppSizes.icon24,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logout button ───────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.errorColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppSizes.radius12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border: Border.all(
              color: AppColors.errorColor.withValues(alpha: 0.25),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded,
                  color: AppColors.errorColor, size: AppSizes.icon20),
              SizedBox(width: AppSizes.spacing8),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: AppTypography.fontSize14,
                  fontWeight: AppTypography.bold,
                  color: AppColors.errorColor,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
