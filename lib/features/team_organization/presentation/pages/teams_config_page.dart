import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Configuration page of the Microsoft Teams tab (Ionic `teams-config`).
///
/// In Ionic this page runs inside Teams and uses the teams-js SDK to save the
/// tab settings. That SDK is not available in Flutter, so this page only shows
/// the hint that is displayed outside of Teams.
class TeamsConfigPage extends StatelessWidget {
  const TeamsConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 56, color: AppColors.medium),
              SizedBox(height: AppDimensions.paddingM),
              Text(
                'Diese Seite wird nur innerhalb von Microsoft Teams verwendet.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
