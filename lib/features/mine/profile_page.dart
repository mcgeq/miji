import 'package:flutter/material.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/l10n/l10n.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.profile),
        backgroundColor: AppColors.primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 16),
            Text('John Doe', style: AppColors.headerText),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.profileDescription,
              style: AppColors.bodyText,
            ),
          ],
        ),
      ),
    );
  }
}
