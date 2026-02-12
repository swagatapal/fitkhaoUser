import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../shared/widgets/logo_widget.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

class NameInputScreen extends ConsumerStatefulWidget {
  const NameInputScreen({super.key});

  @override
  ConsumerState<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends ConsumerState<NameInputScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  String _name = '';

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _handleContinue() {
    // Save name to auth provider
    ref.read(authProvider.notifier).saveName(_name);

    // Navigate to address input screen
    context.go(RouteNames.addressInput);
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive values
    final horizontalPadding = context.horizontalPadding;
    final verticalPadding = context.verticalPadding;
    final spacing8 = context.responsiveSpacing(8.0);
    final spacing16 = context.responsiveSpacing(16.0);
    final spacing24 = context.responsiveSpacing(24.0);
    final spacing40 = context.responsiveSpacing(40.0);
    final spacing48 = context.responsiveSpacing(48.0);
    final radiusSmall = context.responsiveSpacing(4.0);

    final inputHeight = context.inputHeight;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing40),
              // Logo
              const Center(child: LogoWidget()),
              SizedBox(height: spacing48),
              // Title
              Text(
                AppStrings.tellUsYourName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: context.responsiveFontSize(22.0),
                  fontFamily: "Lato",
                ),
              ),
              SizedBox(height: spacing8),
              // Subtitle
              Text(
                AppStrings.pleaseEnterYourName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF2B292A),
                  fontWeight: FontWeight.w400,
                  fontSize: context.responsiveFontSize(16.0),
                  fontFamily: "Lato",
                ),
              ),
              SizedBox(height: spacing40),
              // Name Input Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppStrings.nameLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: context.responsiveFontSize(14.0),
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacing4),
                      Text(
                        '*',
                        style: TextStyle(
                          color: AppColors.errorColor,
                          fontSize: context.responsiveFontSize(AppTypography.fontSize16),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing8),
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) {
                      setState(() {
                        _name = value.trim();
                      });
                    },
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: context.responsiveFontSize(16.0),
                      fontFamily: 'Lato',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Your Name',
                      hintStyle: TextStyle(
                        fontSize: context.responsiveFontSize(16.0),
                        color: AppColors.textSecondary,
                        fontFamily: 'Lato',
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.responsiveSpacing(20.0),
                        vertical: context.responsiveSpacing(16.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          context.responsiveSpacing(4.0),
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.borderColor,
                          width: AppSizes.borderMedium,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          context.responsiveSpacing(4.0),
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: AppSizes.borderMedium,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing8),
                  Text(
                    AppStrings.putYourFirstAndLastName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: context.responsiveFontSize(12.0),
                      fontFamily: 'Lato',
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing24),
              // Continue Button
              PrimaryButton(
                text: AppStrings.continueText,
                textColor: Colors.white,
                onPressed: _name.isNotEmpty ? _handleContinue : null,
                isLoading: false,
                height: AppSizes.buttonHeight,
                disabledBackgroundColor: const Color(0xFFA0D488),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
