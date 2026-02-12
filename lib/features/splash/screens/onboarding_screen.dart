import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/responsive_utils.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingData> _onboardingData = [
    OnboardingData(
      image: "assets/images/o1.png",
      title: "Select\nYour\nHealth\nRecipe",
      titleGreenPart: "Select\nYour\n",
      titleWhitePart: "Health\nRecipe",
    ),
    OnboardingData(
      image: "assets/images/o2.png",
      title: "We\nCook\nIt For\nYou",
      titleGreenPart: "Choose\nYour\n",
      titleWhitePart: "Favorite\nMeal",
    ),
    OnboardingData(
      image: "assets/images/o3.png",
      title: "We\nDeliver\nIt to Your\nDoorstep",
      titleGreenPart: "Get\nHealthy\n",
      titleWhitePart: "Food\nDelivered",
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _nextPage() {
    if (_currentIndex < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: AppSizes.durationFast),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToPhoneAuth();
    }
  }

  void _navigateToPhoneAuth() {
    context.go(RouteNames.phoneAuth);
  }

  @override
  Widget build(BuildContext context) {
    final spacing20 = context.responsiveSpacing(20.0);
    final spacing24 = context.responsiveSpacing(24.0);
    final spacing12 = context.responsiveSpacing(12.0);

    return Scaffold(
      backgroundColor: const Color(0xFF2B292A),
      body: SafeArea(
        child: Column(
          children: [
            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(_onboardingData[index]);
                },
              ),
            ),

            // Bottom section with indicators and buttons
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.horizontalPadding,
                vertical: spacing24,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _onboardingData.length,
                          (index) => _buildIndicator(index),
                        ),
                      ),

                      SizedBox(height: spacing12),

                      // Skip and Next buttons
                      GestureDetector(
                        onTap: _navigateToPhoneAuth,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing20,
                            vertical: context.responsiveSpacing(12.0),
                          ),
                          child: Text(
                            "Skip",
                            style: TextStyle(
                              fontSize: context.responsiveFontSize(AppTypography.fontSize20),
                              fontWeight: AppTypography.medium,
                              color: Colors.white,
                              fontFamily: AppTypography.fontFamily,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Next/Get Started button
                  GestureDetector(
                    onTap: _nextPage,
                    child: Container(
                      width: AppSizes.nextButtonSize,
                      height: AppSizes.nextButtonSize,
                      decoration: BoxDecoration(
                        color: Color(0xFF5D9E40),
                        borderRadius: BorderRadius.circular(AppSizes.radius8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: AppSizes.icon32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Image
        Center(
          child: Image.asset(
            data.image,
            height: AppSizes.onboardingImageHeight,
            width: AppSizes.onboardingImageWidth,
            fit: BoxFit.contain,
          ),
        ),

        SizedBox(height: context.responsiveSpacing(60.0)),

        // Title with green and white parts
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: context.responsiveFontSize(AppTypography.fontSize60),
                fontWeight: AppTypography.bold,
                fontFamily: AppTypography.fontFamily,
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: data.titleGreenPart,
                  style: const TextStyle(color: Color(0xFF5D9E40)),
                ),
                TextSpan(
                  text: data.titleWhitePart,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(int index) {
    final isActive = _currentIndex == index;
    final spacing8 = context.responsiveSpacing(AppSizes.spacing8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: AppSizes.durationFast),
      margin: EdgeInsets.symmetric(horizontal: spacing8 / 2),
      width: isActive
          ? context.responsiveSpacing(29.0)
          : context.responsiveSpacing(AppSizes.spacing12),
      height: context.responsiveSpacing(AppSizes.spacing12),
      decoration: BoxDecoration(
        color: isActive ? Color(0xFF5D9E40) : const Color(0xFF5C5C5C),
        borderRadius: BorderRadius.circular(AppSizes.radius6),
      ),
    );
  }
}

class OnboardingData {
  final String image;
  final String title;
  final String titleGreenPart;
  final String titleWhitePart;

  OnboardingData({
    required this.image,
    required this.title,
    required this.titleGreenPart,
    required this.titleWhitePart,
  });
}
