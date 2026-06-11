// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:intl/intl.dart';
// import '../../../core/constants/app_colors.dart';
// import '../../../core/constants/app_sizes.dart';
// import '../../../core/constants/app_strings.dart';
// import '../../../core/constants/app_typography.dart';
// import '../../../core/router/route_names.dart';
// import '../../../core/utils/responsive_utils.dart';
// import '../../../shared/widgets/logo_widget.dart';
// import '../../../shared/widgets/primary_button.dart';
// import '../providers/auth_provider.dart';
//
// class BmiAnalysisScreen extends ConsumerStatefulWidget {
//   const BmiAnalysisScreen({super.key});
//
//   @override
//   ConsumerState<BmiAnalysisScreen> createState() => _BmiAnalysisScreenState();
// }
//
// class _BmiAnalysisScreenState extends ConsumerState<BmiAnalysisScreen> {
//   // Form fields
//   String _gender = 'female'; // female or male
//   DateTime? _selectedDate;
//   String _height = '';
//   String _weight = '';
//   bool _doesExercise = true;
//
//   // Controllers
//   final TextEditingController _dateController = TextEditingController();
//   final TextEditingController _heightController = TextEditingController();
//   final TextEditingController _weightController = TextEditingController();
//
//   // Focus nodes
//   final FocusNode _dateFocusNode = FocusNode();
//   final FocusNode _heightFocusNode = FocusNode();
//   final FocusNode _weightFocusNode = FocusNode();
//
//   @override
//   void dispose() {
//     _dateController.dispose();
//     _heightController.dispose();
//     _weightController.dispose();
//     _dateFocusNode.dispose();
//     _heightFocusNode.dispose();
//     _weightFocusNode.dispose();
//     super.dispose();
//   }
//
//   bool get _isFormValid {
//     return _selectedDate != null &&
//         _height.isNotEmpty &&
//         _weight.isNotEmpty &&
//         double.tryParse(_height) != null &&
//         double.tryParse(_weight) != null;
//   }
//
//   void _handleContinue() {
//     if (!_isFormValid) return;
//
//     // Calculate BMI
//     final double heightInCm = double.parse(_height);
//     final double weightInKg = double.parse(_weight);
//     final double bmi = _calculateBMI(heightInCm, weightInKg);
//
//     // Calculate health score based on BMI and exercise
//     final Map<String, dynamic> healthData = _calculateHealthScore(bmi, _doesExercise);
//
//     // Save personal info and health data to auth provider
//     ref.read(authProvider.notifier).savePersonalInfo(
//       gender: _gender,
//       dateOfBirth: _selectedDate!,
//       height: heightInCm,
//       weight: weightInKg,
//       doesExercise: _doesExercise,
//       age: double.parse(calculateAge(_selectedDate!).toString())
//     );
//
//     ref.read(authProvider.notifier).saveHealthData(
//       bmi: bmi,
//       healthScore: healthData['healthScore'],
//     );
//
//     // Navigate to health score screen with calculated data
//     context.pushNamed(
//       RouteNames.healthScore,
//       extra: healthData,
//     );
//   }
//
//   /// Calculate BMI using the formula: BMI = weight(kg) / (height(m))^2
//   double _calculateBMI(double heightInCm, double weightInKg) {
//     final double heightInMeters = heightInCm / 100;
//     return weightInKg / (heightInMeters * heightInMeters);
//   }
//
//   /// Calculate health score based on BMI and exercise habits
//   Map<String, dynamic> _calculateHealthScore(double bmi, bool doesExercise) {
//     int baseScore = 0;
//     String scoreLevel = '';
//
//     // BMI Categories (WHO standards):
//     // Underweight: < 18.5
//     // Normal: 18.5 - 24.9
//     // Overweight: 25 - 29.9
//     // Obese: >= 30
//
//     if (bmi < 18.5) {
//       // Underweight
//       baseScore = 40;
//       scoreLevel = 'Low';
//     } else if (bmi >= 18.5 && bmi < 25) {
//       // Normal - Healthy range
//       baseScore = 75;
//       scoreLevel = 'Good';
//     } else if (bmi >= 25 && bmi < 30) {
//       // Overweight
//       baseScore = 55;
//       scoreLevel = 'Medium';
//     } else {
//       // Obese
//       baseScore = 35;
//       scoreLevel = 'Low';
//     }
//
//     // Add bonus for exercising
//     if (doesExercise) {
//       baseScore += 5;
//       // Upgrade level if score crosses threshold
//       if (baseScore >= 70 && scoreLevel == 'Medium') {
//         scoreLevel = 'Good';
//       } else if (baseScore >= 50 && scoreLevel == 'Low') {
//         scoreLevel = 'Medium';
//       }
//     }
//
//     // Ensure score is between 0-100
//     baseScore = baseScore.clamp(0, 100);
//
//     return {
//       'healthScore': baseScore,
//       'scoreLevel': scoreLevel,
//       'bmi': bmi.toStringAsFixed(1),
//     };
//   }
//
//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
//       firstDate: DateTime(1950),
//       lastDate: DateTime.now(),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: AppColors.primaryGreen,
//               onPrimary: Colors.white,
//               surface: Colors.white,
//               onSurface: AppColors.textPrimary,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );
//
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//         _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
//       });
//     }
//   }
//
//   int calculateAge(DateTime dob) {
//     DateTime today = DateTime.now();
//
//     int age = today.year - dob.year;
//
//     // If today's date is before the birthday this year → subtract 1
//     if (today.month < dob.month ||
//         (today.month == dob.month && today.day < dob.day)) {
//       age--;
//     }
//
//     return age;
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     // Get responsive values
//     final horizontalPadding = context.horizontalPadding;
//     final spacing8 = context.responsiveSpacing(8.0);
//     final spacing12 = context.responsiveSpacing(12.0);
//     final spacing16 = context.responsiveSpacing(16.0);
//     final spacing20 = context.responsiveSpacing(20.0);
//     final spacing24 = context.responsiveSpacing(24.0);
//     final spacing32 = context.responsiveSpacing(32.0);
//
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: EdgeInsets.symmetric(
//             horizontal: horizontalPadding,
//             vertical: spacing24,
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Logo
//               const Center(child: LogoWidget()),
//               SizedBox(height: spacing20),
//
//               // Title
//               Text(
//                 AppStrings.letsAnalyseYourBMI,
//                 style: TextStyle(
//                   fontSize: context.responsiveFontSize(20.0),
//                   fontWeight: FontWeight.w700,
//                   color: AppColors.textPrimary,
//                   fontFamily: 'Lato',
//                 ),
//               ),
//               SizedBox(height: spacing12),
//
//               // Subtitle
//               Text(
//                 AppStrings.enterHeightWeightAge,
//                 style: TextStyle(
//                   fontSize: context.responsiveFontSize(18.0),
//                   color: AppColors.textSecondary,
//                   fontWeight: FontWeight.w400,
//                   fontFamily: 'Lato',
//                 ),
//               ),
//               SizedBox(height: spacing32),
//
//               // Gender Selection
//               Row(
//                 children: [
//                   Expanded(
//                     child: _buildGenderButton(
//                       label: AppStrings.female,
//                       icon: Icons.female,
//                       isSelected: _gender == 'female',
//                       onTap: () {
//                         setState(() {
//                           _gender = 'female';
//                         });
//                       },
//                     ),
//                   ),
//                   SizedBox(width: spacing16),
//                   Expanded(
//                     child: _buildGenderButton(
//                       label: AppStrings.male,
//                       icon: Icons.male,
//                       isSelected: _gender == 'male',
//                       onTap: () {
//                         setState(() {
//                           _gender = 'male';
//                         });
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(height: spacing20),
//
//               // Date of Birth
//               Text(
//                 '${AppStrings.dateOfBirth} *',
//                 style: TextStyle(
//                   fontSize: context.responsiveFontSize(14.0),
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.textPrimary,
//                   fontFamily: 'Lato',
//                 ),
//               ),
//               SizedBox(height: spacing8),
//               _buildDateField(),
//               SizedBox(height: spacing20),
//
//               // Height
//               Text(
//                 '${AppStrings.heightInCms} *',
//                 style: TextStyle(
//                   fontSize: context.responsiveFontSize(14.0),
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.textPrimary,
//                   fontFamily: 'Lato',
//                 ),
//               ),
//               SizedBox(height: spacing8),
//               _buildInputField(
//                 controller: _heightController,
//                 focusNode: _heightFocusNode,
//                 hint: AppStrings.heightHint,
//                 keyboardType: TextInputType.number,
//                 onChanged: (value) {
//                   setState(() {
//                     _height = value;
//                   });
//                 },
//               ),
//               SizedBox(height: spacing20),
//
//               // Weight
//               Text(
//                 '${AppStrings.weightInKg} *',
//                 style: TextStyle(
//                   fontSize: context.responsiveFontSize(14.0),
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.textPrimary,
//                   fontFamily: 'Lato',
//                 ),
//               ),
//               SizedBox(height: spacing8),
//               _buildInputField(
//                 controller: _weightController,
//                 focusNode: _weightFocusNode,
//                 hint: AppStrings.weightHint,
//                 keyboardType: TextInputType.number,
//                 onChanged: (value) {
//                   setState(() {
//                     _weight = value;
//                   });
//                 },
//               ),
//               SizedBox(height: spacing20),
//
//               // Workout Information
//               Text(
//                 '${AppStrings.workoutInformation} *',
//                 style: TextStyle(
//                   fontSize: context.responsiveFontSize(14.0),
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.textPrimary,
//                   fontFamily: 'Lato',
//                 ),
//               ),
//               SizedBox(height: spacing16),
//
//               // Exercise Options
//               Row(
//                 children: [
//                   Expanded(
//                     child: _buildExerciseButton(
//                       label: AppStrings.iExercise,
//                       icon: Icons.fitness_center,
//                       isSelected: _doesExercise,
//                       onTap: () {
//                         setState(() {
//                           _doesExercise = true;
//                         });
//                       },
//                     ),
//                   ),
//                   SizedBox(width: spacing16),
//                   Expanded(
//                     child: _buildExerciseButton(
//                       label: AppStrings.iDontExercise,
//                       icon: Icons.event_busy,
//                       isSelected: !_doesExercise,
//                       onTap: () {
//                         setState(() {
//                           _doesExercise = false;
//                         });
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(height: spacing24),
//
//               // Continue Button
//               PrimaryButton(
//                 text: AppStrings.continueText,
//                 onPressed: _isFormValid ? _handleContinue : null,
//                 textColor: Colors.white,
//                 height: context.inputHeight,
//                 isLoading: false,
//               ),
//               SizedBox(height: spacing16),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildGenderButton({
//     required String label,
//     required IconData icon,
//     required bool isSelected,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         height: context.inputHeight,
//         decoration: BoxDecoration(
//           color: isSelected ? Color(0xFF5D9E40) : Colors.white,
//           borderRadius: BorderRadius.circular(context.responsiveSpacing(AppSizes.radius42)),
//           border: Border.all(
//             color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
//             width: AppSizes.borderNormal,
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               icon,
//               color: isSelected ? Colors.white : Color(0xFF5D9E40),
//               size: AppSizes.icon24,
//             ),
//             SizedBox(width: context.responsiveSpacing(8.0)),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: context.responsiveFontSize(14.0),
//                 fontWeight: FontWeight.w400,
//                 color: isSelected ? Colors.white : AppColors.textPrimary,
//                 fontFamily: 'Lato',
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildExerciseButton({
//     required String label,
//     required IconData icon,
//     required bool isSelected,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         height: context.inputHeight,
//         decoration: BoxDecoration(
//           color: isSelected ? Color(0xFF5D9E40): Colors.white,
//           borderRadius: BorderRadius.circular(context.responsiveSpacing(AppSizes.radius42)),
//           border: Border.all(
//             color: isSelected ? AppColors.primaryGreen : AppColors.borderColor,
//             width: AppSizes.borderNormal,
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               icon,
//               color: isSelected ? Colors.white : AppColors.primaryGreen,
//               size: AppSizes.icon20,
//             ),
//             SizedBox(width: context.responsiveSpacing(8.0)),
//             Flexible(
//               child: Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: context.responsiveFontSize(14.0),
//                   fontWeight: FontWeight.w400,
//                   color: isSelected ? Colors.white : AppColors.textPrimary,
//                   fontFamily: 'Lato',
//                 ),
//                 textAlign: TextAlign.center,
//                 maxLines: AppSizes.maxLines1,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDateField() {
//     return GestureDetector(
//       onTap: () => _selectDate(context),
//       child: AbsorbPointer(
//         child: TextField(
//           controller: _dateController,
//           focusNode: _dateFocusNode,
//           readOnly: true,
//           style: TextStyle(
//             fontSize: context.responsiveFontSize(16.0),
//             color: AppColors.textPrimary,
//             fontFamily: 'Lato',
//           ),
//           decoration: InputDecoration(
//             hintText: AppStrings.dateOfBirthHint,
//             hintStyle: TextStyle(
//               fontSize: context.responsiveFontSize(16.0),
//               color: AppColors.textSecondary,
//               fontFamily: 'Lato',
//             ),
//             filled: true,
//             fillColor: Colors.white,
//             suffixIcon: const Icon(
//               Icons.calendar_today,
//               color: AppColors.textSecondary,
//             ),
//             contentPadding: EdgeInsets.symmetric(
//               horizontal: context.responsiveSpacing(20.0),
//               vertical: context.responsiveSpacing(16.0),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(
//                 context.responsiveSpacing(AppSizes.radius4),
//               ),
//               borderSide: const BorderSide(
//                 color: AppColors.borderColor,
//                 width: AppSizes.borderMedium,
//               ),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(
//                 context.responsiveSpacing(AppSizes.radius4),
//               ),
//               borderSide: const BorderSide(
//                 color: AppColors.primaryGreen,
//                 width: AppSizes.borderMedium,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildInputField({
//     required TextEditingController controller,
//     required FocusNode focusNode,
//     required String hint,
//     required Function(String) onChanged,
//     TextInputType? keyboardType,
//   }) {
//     return TextField(
//       controller: controller,
//       focusNode: focusNode,
//       keyboardType: keyboardType,
//       inputFormatters: keyboardType == TextInputType.number
//           ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
//           : null,
//       style: TextStyle(
//         fontSize: context.responsiveFontSize(16.0),
//         color: AppColors.textPrimary,
//         fontFamily: 'Lato',
//       ),
//       onChanged: onChanged,
//       decoration: InputDecoration(
//         hintText: hint,
//         hintStyle: TextStyle(
//           fontSize: context.responsiveFontSize(16.0),
//           color: AppColors.textSecondary,
//           fontFamily: 'Lato',
//         ),
//         filled: true,
//         fillColor: Colors.white,
//         contentPadding: EdgeInsets.symmetric(
//           horizontal: context.responsiveSpacing(20.0),
//           vertical: context.responsiveSpacing(16.0),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(
//             context.responsiveSpacing(AppSizes.radius4),
//           ),
//           borderSide: const BorderSide(
//             color: AppColors.borderColor,
//             width: AppSizes.borderMedium,
//           ),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(
//             context.responsiveSpacing(AppSizes.radius4),
//           ),
//           borderSide: const BorderSide(
//             color: AppColors.primaryGreen,
//             width: AppSizes.borderMedium,
//           ),
//         ),
//       ),
//     );
//   }
// }
