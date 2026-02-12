import 'package:fitkhao_user/core/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Image.asset(
            "assets/images/coming_soon.png",
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            fit: BoxFit.cover,
          ),

          Center(
            child: Text("Coming Soon", style: TextStyle(
              fontSize: context.responsiveFontSize(24.0),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'Lato',
            ),),
          )
        ],
      ),
    );
  }
}
