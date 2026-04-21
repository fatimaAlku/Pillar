import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_locale_controller.dart';
import '../../../../core/state/theme_mode_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../subjects/presentation/screens/subjects_manage_screen.dart';

class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  void _showComingSoon(BuildContext context, String label) {
    final strings = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.comingSoonFor(label)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final appLocale = ref.watch(appLocaleProvider);
    final isLightMode = themeMode != ThemeMode.dark;
    final isEnglish = appLocale.languageCode != 'ar';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Center(
          child: Text(
            '',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: colorScheme.surfaceContainerHigh,
                child: Icon(
                  Icons.person_rounded,
                  size: 46,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: colorScheme.surface,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _showComingSoon(context, 'Edit profile photo'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'fatimaa.alkuwaiti',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            'fatimaa.alkuwaiti@gmail.com',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: const Color(0xFF1F285C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              _ProfileMenuTile(
                icon: Icons.menu_book_outlined,
                title: strings.myCourses,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const SubjectsManageScreen(),
                    ),
                  );
                },
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.language_rounded,
                title: strings.appLanguage,
                trailing: _PillToggle(
                  leftLabel: 'EN',
                  rightLabel: 'AR',
                  isLeftActive: isEnglish,
                  onChanged: (isLeftActive) {
                    ref.read(appLocaleProvider.notifier).setLocale(
                      isLeftActive ? const Locale('en') : const Locale('ar'),
                    );
                  },
                ),
                onTap: () => ref.read(appLocaleProvider.notifier).toggleLocale(),
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.light_mode_rounded,
                title: strings.modeSwitch,
                trailing: _PillToggle(
                  leftLabel: strings.light,
                  rightLabel: strings.dark,
                  isLeftActive: isLightMode,
                  onChanged: (isLeftActive) {
                    ref.read(themeModeProvider.notifier).setThemeMode(
                      isLeftActive ? ThemeMode.light : ThemeMode.dark,
                    );
                  },
                ),
                onTap: () {
                  ref.read(themeModeProvider.notifier).toggleThemeMode();
                },
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.insights_outlined,
                title: strings.progress,
                onTap: () => _showComingSoon(context, strings.progress),
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.lock_outline_rounded,
                title: strings.passwordChange,
                onTap: () => _showComingSoon(context, strings.passwordChange),
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.privacy_tip_outlined,
                title: strings.privacyPolicy,
                onTap: () => _showComingSoon(context, strings.privacyPolicy),
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.info_outline_rounded,
                title: strings.about,
                onTap: () => _showComingSoon(context, strings.about),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF44336),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () =>
              ref.read(authFormControllerProvider.notifier).signOut(),
          child: Text(
            strings.logout,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            strings.allRightsReserved,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    const tileTextColor = Color(0xFFEFF2FF);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      onTap: onTap,
      leading: Icon(icon, color: tileTextColor),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tileTextColor,
              fontWeight: FontWeight.w500,
            ),
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: tileTextColor,
          ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        height: 1,
        color: Color(0x40DDE4FF),
      ),
    );
  }
}

class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftActive,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool isLeftActive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF33407A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleSegment(
            label: leftLabel,
            active: isLeftActive,
            onTap: () => onChanged(true),
          ),
          _ToggleSegment(
            label: rightLabel,
            active: !isLeftActive,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1CB5A2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFEFF2FF),
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
