import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_strings.dart';

/// Explains local study reminders and links to OS notification settings.
class RemindersNotificationsScreen extends StatelessWidget {
  const RemindersNotificationsScreen({super.key});

  bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _openNotificationSettings(BuildContext context) async {
    final strings = AppStrings.of(context);
    if (kIsWeb) return;

    final opened = _isIos
        ? await _openIosNotificationSettings()
        : await _openAndroidOrFallbackSettings();

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.remindersCouldNotOpenSettings)),
      );
    }
  }

  /// iOS: `app-settings:` is reliable. `app_settings` notification type can throw
  /// on some OS versions when the method channel returns an error.
  Future<bool> _openIosNotificationSettings() async {
    final uri = Uri.parse('app-settings:');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } on Object {
      // Fall through to app_settings.
    }
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.settings);
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> _openAndroidOrFallbackSettings() async {
    if (_isAndroid) {
      try {
        await AppSettings.openAppSettings(
          type: AppSettingsType.notification,
        );
        return true;
      } on Object {
        try {
          await AppSettings.openAppSettings();
          return true;
        } on Object {
          return false;
        }
      }
    }
    try {
      await AppSettings.openAppSettings();
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.remindersNotificationsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: Icon(
              Icons.notifications_active_outlined,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            strings.remindersNotificationsDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 28),
          if (kIsWeb)
            Text(
              strings.remindersNotAvailableOnWeb,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            FilledButton.icon(
              onPressed: () => _openNotificationSettings(context),
              icon: const Icon(Icons.settings_suggest_outlined),
              label: Text(strings.remindersOpenSystemSettings),
            ),
          if (!kIsWeb && _isIos) ...[
            const SizedBox(height: 16),
            Text(
              strings.remindersIosSettingsFootnote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
