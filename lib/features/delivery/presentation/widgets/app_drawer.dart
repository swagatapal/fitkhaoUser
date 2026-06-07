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
      backgroundColor: Color(0xFFF5F7F5),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: AppMenuContent(),
    );
  }
}

// ─── Navigation model ────────────────────────────────────────────────────────

/// A single navigation row's data — keeps the list declarative so the layout,
/// staggered animation and styling are computed uniformly.
class _NavItem {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}

/// Drawer body — animated gradient header, grouped cards and footer.
///
/// Navigation / contact / logout behaviour is delegated to [ProfileMenuActions]
/// so the full-screen `ProfileMenuScreen` reuses exactly the same logic.
class AppMenuContent extends ConsumerStatefulWidget {
  const AppMenuContent({super.key});

  @override
  ConsumerState<AppMenuContent> createState() => _AppMenuContentState();
}

class _AppMenuContentState extends ConsumerState<AppMenuContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Declarative groups → rendered as cards. Behaviour preserved verbatim.
    //final account = <_NavItem>[
    //   _NavItem(
    //     icon: Icons.person_outline_rounded,
    //     color: AppColors.primaryGreen,
    //     label: 'Profile Details',
    //     subtitle: 'Health, body & goals',
    //     onTap: () => ProfileMenuActions.open(
    //         context, const DetailedHealthInfoScreen(),
    //         insideDrawer: true),
    //   ),
    //   _NavItem(
    //     icon: Icons.edit_outlined,
    //     color: const Color(0xFF2E7CF6),
    //     label: 'Edit Profile',
    //     subtitle: 'Name, address & photo',
    //     onTap: () => ProfileMenuActions.open(context, const EditProfileScreen(),
    //         insideDrawer: true),
    //   ),
    // ];

    final orders = <_NavItem>[
      _NavItem(
        icon: Icons.schedule_rounded,
        color: const Color(0xFFC66301),
        label: 'Orders',
        subtitle: 'Track active orders',
        onTap: () => ProfileMenuActions.open(
            context, const HistoryScreen(initialTab: HistoryTab.upcoming),
            insideDrawer: true),
      ),
      _NavItem(
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF20A39E),
        label: 'Order History',
        subtitle: 'Your past orders',
        onTap: () => ProfileMenuActions.open(
            context, const HistoryScreen(initialTab: HistoryTab.delivered),
            insideDrawer: true),
      ),
      _NavItem(
        icon: Icons.card_membership_outlined,
        color: const Color(0xFF8B5CF6),
        label: 'Membership',
        subtitle: 'Plans & wallet balance',
        onTap: () => ProfileMenuActions.open(
            context, const SubscriptionPlanScreen(),
            insideDrawer: true),
      ),
    ];

    final more = <_NavItem>[
      _NavItem(
        icon: Icons.notifications_none_rounded,
        color: const Color(0xFFF5A623),
        label: 'Notifications',
        subtitle: 'Alerts & updates',
        onTap: () => ProfileMenuActions.open(
            context, const NotificationScreen(),
            insideDrawer: true),
      ),
      _NavItem(
        icon: Icons.support_agent_outlined,
        color: const Color(0xFF1E9E63),
        label: 'Help & Support',
        subtitle: 'We’re here to help',
        onTap: () =>
            ProfileMenuActions.showContactUs(context, insideDrawer: true),
      ),
      _NavItem(
        icon: Icons.policy_outlined,
        color: const Color(0xFF607D8B),
        label: 'Terms & Conditions',
        subtitle: 'Policies & privacy',
        onTap: () => ProfileMenuActions.open(context, const PolicyScreen(),
            insideDrawer: true),
      ),

    ];

    // Ordered list of animated blocks — each gets a sequential stagger slot.
    final blocks = <Widget>[
      const _KitchenSelectorSection(),
      //const _SectionLabel('Account'),
      //_MenuCard(items: account),
      const _SectionLabel('Orders'),
      _MenuCard(items: orders),
      const _SectionLabel('More'),
      _MenuCard(items: more),
      const SizedBox(height: AppSizes.spacing8),
      _LogoutButton(
        onTap: () => ProfileMenuActions.confirmLogout(context, ref),
      ),
    ];

    return Column(
      children: [
        _Header(animation: _entrance, authState: authState),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacing16,
              AppSizes.spacing16,
              AppSizes.spacing16,
              AppSizes.spacing8,
            ),
            itemCount: blocks.length,
            itemBuilder: (_, i) => _Stagger(
              parent: _entrance,
              index: i + 1, // header consumes slot 0
              count: blocks.length + 1,
              child: blocks[i],
            ),
          ),
        ),
        const _Footer(),
      ],
    );
  }
}

// ─── Staggered entrance wrapper ──────────────────────────────────────────────

/// Fades + slides its [child] in along the shared [parent] controller, on a
/// per-[index] time slice so blocks cascade rather than appear at once.
class _Stagger extends StatelessWidget {
  final Animation<double> parent;
  final int index;
  final int count;
  final Widget child;

  const _Stagger({
    required this.parent,
    required this.index,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index / (count + 1)) * 0.55;
    final anim = CurvedAnimation(
      parent: parent,
      curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(-0.18, 0), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Animation<double> animation;
  final dynamic authState;

  const _Header({required this.animation, required this.authState});

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

    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSizes.spacing20,
        MediaQuery.of(context).padding.top + AppSizes.spacing20,
        AppSizes.spacing20,
        AppSizes.spacing24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3E6B33), Color(0xFF6BA84F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative translucent circles
          Positioned(top: -42, right: -28, child: _circle(110, 0.10)),
          Positioned(bottom: -34, left: -30, child: _circle(78, 0.08)),

          FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.12),
                end: Offset.zero,
              ).animate(fade),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Avatar(
                          hasImage: hasImage,
                          imgUrl: imgUrl,
                          initial: initial),
                      // const Spacer(),
                      // _EditChip(
                      //   onTap: () => ProfileMenuActions.open(
                      //       context, const EditProfileScreen(),
                      //       insideDrawer: true),
                      // ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spacing16),
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
                        Icon(Icons.phone_outlined,
                            size: AppSizes.icon14,
                            color: Colors.white.withValues(alpha: 0.85)),
                        const SizedBox(width: AppSizes.spacing6),
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
          ),
        ],
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
}

class _Avatar extends StatelessWidget {
  final bool hasImage;
  final String? imgUrl;
  final String initial;

  const _Avatar(
      {required this.hasImage, required this.imgUrl, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: Colors.white,
        backgroundImage: hasImage ? NetworkImage(imgUrl!) : null,
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
    );
  }
}

class _EditChip extends StatelessWidget {
  final VoidCallback onTap;
  const _EditChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppSizes.radius20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radius20),
        child: const Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.spacing12, vertical: AppSizes.spacing6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined,
                  size: AppSizes.icon14, color: Colors.white),
              SizedBox(width: AppSizes.spacing4),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: AppTypography.fontSize12,
                  fontWeight: AppTypography.semiBold,
                  color: Colors.white,
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

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSizes.spacing4,
        top: AppSizes.spacing16,
        bottom: AppSizes.spacing8,
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
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

// ─── Grouped card + rows ─────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<_NavItem> items;
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
            _MenuRow(item: items[i]),
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

class _MenuRow extends StatelessWidget {
  final _NavItem item;
  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing16,
          vertical: AppSizes.spacing12,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radius12),
              ),
              child: Icon(item.icon, color: item.color, size: AppSizes.icon20),
            ),
            const SizedBox(width: AppSizes.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight: AppTypography.semiBold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSize12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: AppSizes.icon24),
          ],
        ),
      ),
    );
  }
}

// ─── Logout ───────────────────────────────────────────────────────────────────

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

// ─── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.spacing20,
        AppSizes.spacing12,
        AppSizes.spacing20,
        MediaQuery.of(context).padding.bottom + AppSizes.spacing12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu,
              size: AppSizes.icon16, color: AppColors.textTertiary),
          const SizedBox(width: AppSizes.spacing6),
          Text(
            'FitKhao • FitRaho  •  v1.0.0',
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
    final hasMultiple = kitchenState.kitchens.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Selected Kitchen'),
        GestureDetector(
          onTap: kitchenState.isLoading || !hasMultiple
              ? null
              : () => _openKitchenPicker(context, ref),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.spacing12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withValues(alpha: 0.10),
                  AppColors.primaryGreen.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSizes.radius16),
              border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacing8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppSizes.radius12),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      size: AppSizes.icon20, color: AppColors.primaryGreen),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: kitchenState.isLoading && selected == null
                      ? const Text(
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
                              const SizedBox(height: 3),
                              _StatusPill(isOpen: isOpen),
                            ],
                          ],
                        ),
                ),
                if (hasMultiple)
                  Container(
                    padding: const EdgeInsets.all(AppSizes.spacing2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primaryGreen, size: AppSizes.icon20),
                  ),
              ],
            ),
          ),
        ),
      ],
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

/// Small open/closed status pill with a soft dot.
class _StatusPill extends StatelessWidget {
  final bool isOpen;
  const _StatusPill({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.primaryGreen : AppColors.errorColor;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacing4),
          Text(
            isOpen ? 'Open now' : 'Closed',
            style: TextStyle(
              fontSize: AppTypography.fontSize12,
              fontWeight: AppTypography.semiBold,
              color: color,
              fontFamily: 'Lato',
            ),
          ),
        ],
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
                  leading: Container(
                    padding: const EdgeInsets.all(AppSizes.spacing8),
                    decoration: BoxDecoration(
                      color: (isSelected
                              ? AppColors.primaryGreen
                              : AppColors.textSecondary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radius12),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                  title: Text(
                    kitchen.name,
                    style: TextStyle(
                      fontSize: AppTypography.fontSize14,
                      fontWeight:
                          isSelected ? AppTypography.bold : AppTypography.medium,
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
