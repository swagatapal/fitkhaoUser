import 'package:fitkhao_user/features/profile/presentation/screens/detailed_health_info_screen.dart';
import 'package:fitkhao_user/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fitkhao_user/features/delivery/presentation/screens/delivery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/responsive_utils.dart';
import '../history/presentation/screens/history_screen.dart';

class MainNavigationTabIndex {
  MainNavigationTabIndex._();

  static const int menu = 0;
  static const int profile = 1;
  static const int history = 2;
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = MainNavigationTabIndex.menu,
  });

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex &&
        _selectedIndex != widget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  // Build the current screen based on selected index
  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return DeliveryScreen(
          onNavigateToProfile: () =>
              _onItemTapped(MainNavigationTabIndex.profile),
        );
      // case 1:
      //   return const DashboardScreen();
      case 1:
        return const DetailedHealthInfoScreen();
      case 2:
        return const HistoryScreen();
      default:
        return DeliveryScreen(
          onNavigateToProfile: () =>
              _onItemTapped(MainNavigationTabIndex.profile),
        );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: true,
        top: false,
        child: Stack(
          children: [
            // Display only the currently selected screen
            _getCurrentScreen(),

            // Floating Bottom Navigation Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomNavigationBar(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing8 = context.responsiveSpacing(8.0);

    return Padding(
      padding: EdgeInsets.only(
        left: spacing16,
        right: spacing16,
        //bottom: spacing16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFF5EC),
          borderRadius: BorderRadius.circular(
            context.responsiveSpacing(AppSizes.radius50),
          ),
          border: Border.all(
            color: AppColors.primaryGreen,
            width: AppSizes.borderThin,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppSizes.opacity08),
              blurRadius: AppSizes.shadowBlur12,
              offset: const Offset(0, 4),
              spreadRadius: AppSizes.shadowSpread0,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing8,
            vertical: spacing8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.food_bank_outlined,
                label: 'Menu',
                index: 0,
              ),
              // _buildNavItem(
              //   context: context,
              //   icon: Icons.settings_system_daydream_sharp,
              //   label: 'Dashboard',
              //   index: 1,
              // ),
              _buildNavItem(
                context: context,
                icon: Icons.person,
                label: 'Profile',
                index: 1,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.history,
                label: 'History',
                index: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final spacing8 = context.responsiveSpacing(8.0);
    final spacing4 = context.responsiveSpacing(4.0);

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: context.responsiveSpacing(4.0),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing8,
            vertical: spacing8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(
              context.responsiveSpacing(AppSizes.spacing30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primaryGreen,
                size: context.responsiveSpacing(AppSizes.icon24),
              ),
              SizedBox(height: spacing4),
              Text(
                label,
                style: TextStyle(
                  fontSize: context.responsiveFontSize(
                    AppTypography.fontSize12,
                  ),
                  fontWeight: AppTypography.medium,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontFamily: AppTypography.fontFamily,
                ),
                textAlign: TextAlign.center,
                maxLines: AppSizes.maxLines1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
