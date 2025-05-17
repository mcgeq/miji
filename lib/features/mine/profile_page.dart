import 'package:flutter/material.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/l10n/l10n.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 16),
              const Text('John Doe', style: AppColors.titleText),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.profileDescription,
                style: AppColors.bodyText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}