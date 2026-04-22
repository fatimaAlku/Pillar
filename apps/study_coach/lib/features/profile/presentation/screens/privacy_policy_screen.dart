import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.privacyPolicy)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            strings.privacyPolicyIntro,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            strings.privacyPolicyLastUpdated,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: strings.privacyPolicyDataWeCollectTitle,
            body: strings.privacyPolicyDataWeCollectBody,
          ),
          _SectionCard(
            title: strings.privacyPolicyHowWeUseDataTitle,
            body: strings.privacyPolicyHowWeUseDataBody,
          ),
          _SectionCard(
            title: strings.privacyPolicyStorageSecurityTitle,
            body: strings.privacyPolicyStorageSecurityBody,
          ),
          _SectionCard(
            title: strings.privacyPolicyYourChoicesTitle,
            body: strings.privacyPolicyYourChoicesBody,
          ),
          _SectionCard(
            title: strings.privacyPolicyContactTitle,
            body: strings.privacyPolicyContactBody,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
