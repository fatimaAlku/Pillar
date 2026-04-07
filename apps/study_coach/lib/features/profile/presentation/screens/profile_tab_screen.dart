import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label - coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.person_rounded,
                size: 44,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'fatima.alkuwaiti',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'fatima.alkuwaiti@gmail.com',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _ProfileMenuTile(
                icon: Icons.insights_outlined,
                title: 'Progress',
                onTap: () => _showComingSoon(context, 'Progress'),
              ),
              const Divider(height: 1),
              _ProfileMenuTile(
                icon: Icons.language_rounded,
                title: 'App language',
                onTap: () => _showComingSoon(context, 'App language'),
              ),
              const Divider(height: 1),
              _ProfileMenuTile(
                icon: Icons.light_mode_rounded,
                title: 'Mode Switch',
                onTap: () => _showComingSoon(context, 'Mode Switch'),
              ),
              const Divider(height: 1),
              _ProfileMenuTile(
                icon: Icons.lock_outline_rounded,
                title: 'Password change',
                onTap: () => _showComingSoon(context, 'Password change'),
              ),
              const Divider(height: 1),
              _ProfileMenuTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => _showComingSoon(context, 'Privacy Policy'),
              ),
              const Divider(height: 1),
              _ProfileMenuTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                onTap: () => _showComingSoon(context, 'About'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () =>
              ref.read(authFormControllerProvider.notifier).signOut(),
          child: const Text('Log out'),
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
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

