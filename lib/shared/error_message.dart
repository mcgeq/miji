import 'package:flutter/material.dart';
import 'package:miji/config/theme/app_colors.dart';

class ErrorMessage extends StatelessWidget {
  final String message;

  const ErrorMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: AppColors.errorColor),
        const SizedBox(width: 8),
        Text(
          message,
          style: const TextStyle(
            color: AppColors.errorColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}