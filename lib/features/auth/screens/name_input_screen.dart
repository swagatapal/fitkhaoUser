import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../models/auth_state.dart';
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
  bool _isProcessing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    ref.read(authProvider.notifier).saveName(_name);

    setState(() => _isProcessing = true);
    // Address fields are not collected here; AuthState defaults ('' / 0.0)
    // are serialised correctly by Address.toFullJson().
    final success = await ref.read(authProvider.notifier).completeRegistration();
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration completed successfully!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    final horizontalPadding = context.horizontalPadding;
    final verticalPadding = context.verticalPadding;
    final spacing8 = context.responsiveSpacing(8.0);
    final spacing24 = context.responsiveSpacing(24.0);
    final spacing40 = context.responsiveSpacing(40.0);
    final spacing48 = context.responsiveSpacing(48.0);

    final isSubmitting = _isProcessing || authState.isLoading;

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
              const Center(child: LogoWidget()),
              SizedBox(height: spacing48),
              Text(
                AppStrings.tellUsYourName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: context.responsiveFontSize(22.0),
                  fontFamily: "Lato",
                ),
              ),
              SizedBox(height: spacing8),
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
                    enabled: !isSubmitting,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
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
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          context.responsiveSpacing(4.0),
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.borderColor,
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
              PrimaryButton(
                text: AppStrings.continueText,
                textColor: Colors.white,
                onPressed: _name.isNotEmpty && !isSubmitting ? _handleContinue : null,
                isLoading: isSubmitting,
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
