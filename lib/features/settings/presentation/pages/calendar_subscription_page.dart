import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../widgets/calendar_subscription_dialog.dart'; // UX_SETTINGS

/// Calendar Subscription Page - allows users to subscribe to attendance calendar
class CalendarSubscriptionPage extends ConsumerWidget {
  const CalendarSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);

    // Generate calendar subscription URL
    // UX_SETTINGS: same edge-function feed as Ionic (ical-tenant)
    final calendarUrl = tenant?.id != null
        ? calendarSubscriptionLink(tenantId: tenant!.id!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender-Abonnement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          // Header icon
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.calendar_month,
                size: 50,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),

          // Description
          Text(
            'Kalender abonnieren',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            'Mit einem Kalender-Abonnement werden alle Termine automatisch in deinem Kalender angezeigt und aktualisiert.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.medium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.paddingXL),

          // Calendar URL Card
          if (calendarUrl != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link, color: AppColors.primary),
                        const SizedBox(width: AppDimensions.paddingS),
                        Text(
                          'Kalender-URL',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingS),
                      decoration: BoxDecoration(
                        color: AppColors.medium.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                      ),
                      child: Text(
                        calendarUrl,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _copyLink(context, calendarUrl),
                        icon: const Icon(Icons.copy),
                        label: const Text('Link kopieren'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingXL),
          ] else ...[
            // Show hint when no tenant selected (Issue #17)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 40),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(
                      'Kein Ensemble ausgewählt',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.paddingXS),
                    Text(
                      'Bitte wähle zuerst ein Ensemble aus, um den Kalender-Link zu erhalten.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.medium),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingXL),
          ],

          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, color: AppColors.primary),
                      const SizedBox(width: AppDimensions.paddingS),
                      Text(
                        'So funktioniert\'s',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.paddingM),

                  _InstructionItem(
                    number: '1',
                    title: 'Link kopieren',
                    description: 'Kopiere den Kalender-Link oben.',
                  ),
                  _InstructionItem(
                    number: '2',
                    title: 'Kalender-App öffnen',
                    description: 'Öffne deine Kalender-App (Google Calendar, Apple Kalender, Outlook, etc.).',
                  ),
                  _InstructionItem(
                    number: '3',
                    title: 'Abonnement hinzufügen',
                    description: 'Suche nach "URL-Abonnement hinzufügen" oder "Kalender per URL abonnieren".',
                  ),
                  _InstructionItem(
                    number: '4',
                    title: 'Link einfügen',
                    description: 'Füge den kopierten Link ein und bestätige.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXL),

          // Platform-specific instructions
          const _PlatformInstructions(),
        ],
      ),
    );
  }

  Future<void> _copyLink(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ToastHelper.showSuccess(context, 'Link kopiert');
    }
  }
}

class _InstructionItem extends StatelessWidget {
  const _InstructionItem({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.medium,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformInstructions extends StatelessWidget {
  const _PlatformInstructions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plattform-spezifische Anleitungen',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),

        // iOS
        _PlatformCard(
          icon: Icons.phone_iphone,
          platform: 'iPhone / iPad',
          steps: [
            'Einstellungen > Kalender > Accounts',
            'Account hinzufügen > Andere',
            'Kalenderabo hinzufügen',
            'URL einfügen und bestätigen',
          ],
        ),

        // Android / Google
        _PlatformCard(
          icon: Icons.android,
          platform: 'Android / Google Calendar',
          steps: [
            'Google Calendar im Browser öffnen',
            'Linke Seitenleiste: "+" bei Andere Kalender',
            '"Per URL" auswählen',
            'URL einfügen und bestätigen',
          ],
        ),

        // Outlook
        _PlatformCard(
          icon: Icons.email_outlined,
          platform: 'Microsoft Outlook',
          steps: [
            'Outlook.com öffnen',
            'Kalender > Kalender hinzufügen',
            '"Aus dem Internet abonnieren"',
            'URL einfügen und bestätigen',
          ],
        ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.icon,
    required this.platform,
    required this.steps,
  });

  final IconData icon;
  final String platform;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(platform),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingM,
              0,
              AppDimensions.paddingM,
              AppDimensions.paddingM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingXS),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$index. ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Expanded(child: Text(step)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
