import 'package:flutter/material.dart';
import 'package:miji/config/theme/app_colors.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        color: AppColors.primaryColor,
        backgroundColor: isDarkMode ? Colors.grey[600] : Colors.grey[200],
        strokeWidth: 4,
      ),
    );
  }
}