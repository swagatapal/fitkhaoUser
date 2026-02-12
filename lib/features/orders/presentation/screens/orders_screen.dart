import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Orders',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontFamily: 'Lato',
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Orders Screen Coming Soon',
          style: TextStyle(
            fontSize: 18,
            color: AppColors.textSecondary,
            fontFamily: 'Lato',
          ),
        ),
      ),
    );
  }
}
