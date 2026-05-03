import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/oauth/google_calendar_oauth_pending_store.dart';
import '../../../../core/oauth/google_oauth_env.dart';
import '../../../../core/state/app_locale_controller.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/state/google_calendar_connection_provider.dart';
import '../../../../core/state/focus_mode_controller.dart';
import '../../../../core/state/theme_mode_controller.dart';
import '../../../study_plan/presentation/controllers/study_plan_firestore_providers.dart';
import '../../data/local/local_profile_avatar_store.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../progress/presentation/screens/progress_details_screen.dart';
import 'about_screen.dart';
import 'password_change_screen.dart';
import 'privacy_policy_screen.dart';
import 'profile_editor_screen.dart';
import 'quiz_history_screen.dart';
import '../../../subjects/presentation/screens/subjects_manage_screen.dart';

class ProfileTabScreen extends ConsumerStatefulWidget {
  const ProfileTabScreen({super.key});

  @override
  ConsumerState<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends ConsumerState<ProfileTabScreen>
    with WidgetsBindingObserver {
  bool _isGoogleBusy = false;
  Map<String, dynamic>? _googleStatus;
  var _googleBumpListenerAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshGoogleStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_googleBumpListenerAttached) return;
    _googleBumpListenerAttached = true;
    ref.listenManual<int>(googleCalendarConnectionBumpProvider, (previous, next) {
      if (previous != null && next > previous) {
        unawaited(_refreshGoogleStatus());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshGoogleStatus());
    }
  }

  Future<void> _refreshGoogleStatus() async {
    final authUser = ref.read(currentAuthUserProvider).valueOrNull;
    if (authUser == null) return;
    try {
      final status =
          await ref.read(googleCalendarSyncRepositoryProvider).googleStatus();
      if (!mounted) return;
      setState(() => _googleStatus = status);
    } catch (_) {
      // Keep profile UI usable even if status lookup fails.
    }
  }

  String _buildOauthState() {
    final nonce = Random().nextInt(1 << 32);
    return '${DateTime.now().millisecondsSinceEpoch}-$nonce';
  }

  String _buildCodeVerifier() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    const length = 64;
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  String _codeChallengeFor(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<void> _startGoogleConnect() async {
    final strings = AppStrings.of(context);
    if (GoogleOauthEnv.clientId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.googleMissingConfig)),
      );
      return;
    }
    final state = _buildOauthState();
    final codeVerifier = _buildCodeVerifier();
    final codeChallenge = _codeChallengeFor(codeVerifier);
    await GoogleCalendarOauthPendingStore.save(state, codeVerifier);
    final redirect = GoogleOauthEnv.redirectUri;
    final authUri = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      {
        'client_id': GoogleOauthEnv.clientId,
        'redirect_uri': redirect.toString(),
        'response_type': 'code',
        'scope':
            'openid email https://www.googleapis.com/auth/calendar.events',
        'access_type': 'offline',
        'prompt': 'consent',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
      },
    );
    final launched = await launchUrl(
      authUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await GoogleCalendarOauthPendingStore.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.googleConnectFailed)),
        );
      }
    }
  }

  Future<void> _disconnectGoogleCalendar() async {
    final strings = AppStrings.of(context);
    if (_isGoogleBusy) return;
    setState(() => _isGoogleBusy = true);
    try {
      await ref
          .read(googleCalendarSyncRepositoryProvider)
          .disconnectGoogleCalendar();
      await _refreshGoogleStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.googleDisconnectedSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.googleDisconnectFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final appLocale = ref.watch(appLocaleProvider);
    final authUser = ref.watch(currentAuthUserProvider).valueOrNull;
    final userEmail = authUser?.email?.trim();
    final hasUserEmail = userEmail != null && userEmail.isNotEmpty;
    final photoUrl = authUser?.photoUrl?.trim();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final avatarId = authUser == null
        ? null
        : ref.watch(localProfileAvatarIdProvider(authUser.uid)).valueOrNull;
    final avatarAssetPath = switch (avatarId) {
      LocalProfileAvatarStore.maleAvatarId => 'assets/avatars/male.svg',
      LocalProfileAvatarStore.femaleAvatarId => 'assets/avatars/female.svg',
      _ => null,
    };
    final localPhotoPath = authUser == null
        ? null
        : ref.watch(localProfilePhotoPathProvider(authUser.uid)).valueOrNull;
    final hasLocalPhoto = localPhotoPath != null && localPhotoPath.isNotEmpty;
    ImageProvider<Object>? profileImage;
    if (hasLocalPhoto) {
      profileImage = FileImage(File(localPhotoPath));
    } else if (hasPhoto) {
      profileImage = NetworkImage(photoUrl);
    }
    final profileName = authUser?.displayName?.trim();
    final hasProfileName = profileName != null && profileName.isNotEmpty;
    final displayName = hasProfileName
        ? profileName
        : (hasUserEmail
            ? userEmail.split('@').first
            : strings.profileUserFallback);
    final displayEmail = hasUserEmail ? userEmail : strings.email;
    final isLightMode = themeMode != ThemeMode.dark;
    final isEnglish = appLocale.languageCode != 'ar';
    final focusModeState = ref.watch(focusModeProvider);
    final googleConnected = _googleStatus?['connected'] == true;
    final googleNeedsReconnect = _googleStatus?['needsReconnect'] == true;
    final googleEmail = (_googleStatus?['email'] as String?)?.trim();
    final statusLabel = googleConnected
        ? strings.googleConnected
        : strings.googleNotConnected;

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
                backgroundImage: avatarAssetPath == null ? profileImage : null,
                child: avatarAssetPath != null
                    ? ClipOval(
                        child: SvgPicture.asset(
                          avatarAssetPath,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      )
                    : profileImage != null
                        ? null
                        : Icon(
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
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileEditorScreen(),
                        ),
                      );
                    },
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
            displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            displayEmail,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: theme.cardTheme.elevation ?? 0,
          shadowColor: theme.cardTheme.shadowColor,
          surfaceTintColor: theme.cardTheme.surfaceTintColor,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.85),
            ),
          ),
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
                icon: Icons.calendar_month_outlined,
                title: strings.googleCalendarSync,
                subtitle: googleConnected && (googleEmail?.isNotEmpty == true)
                    ? googleEmail
                    : statusLabel,
                trailing: _isGoogleBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        googleConnected
                            ? (googleNeedsReconnect
                                ? strings.reconnectGoogleCalendar
                                : strings.disconnectGoogleCalendar)
                            : strings.connectGoogleCalendar,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                onTap: () {
                  if (_isGoogleBusy) return;
                  if (googleConnected && !googleNeedsReconnect) {
                    unawaited(_disconnectGoogleCalendar());
                    return;
                  }
                  unawaited(_startGoogleConnect());
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
                          isLeftActive
                              ? const Locale('en')
                              : const Locale('ar'),
                        );
                  },
                ),
                onTap: () =>
                    ref.read(appLocaleProvider.notifier).toggleLocale(),
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
                icon: Icons.center_focus_strong_rounded,
                title: strings.focusMode,
                trailing: _PillToggle(
                  leftLabel: strings.off,
                  rightLabel: strings.on,
                  isLeftActive: !focusModeState.enabled,
                  onChanged: (isLeftActive) {
                    ref
                        .read(focusModeProvider.notifier)
                        .setEnabled(!isLeftActive);
                  },
                ),
                onTap: () =>
                    ref.read(focusModeProvider.notifier).toggle(),
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.insights_outlined,
                title: strings.progress,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProgressDetailsScreen(),
                    ),
                  );
                },
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.history_rounded,
                title: strings.history,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const QuizHistoryScreen(),
                    ),
                  );
                },
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.lock_outline_rounded,
                title: strings.passwordChange,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const PasswordChangeScreen(),
                    ),
                  );
                },
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.privacy_tip_outlined,
                title: strings.privacyPolicy,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              const _TileDivider(),
              _ProfileMenuTile(
                icon: Icons.info_outline_rounded,
                title: strings.about,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () =>
              ref.read(authFormControllerProvider.notifier).signOut(),
          child: Text(
            strings.logout,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onError,
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
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = colorScheme.onSurface;
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      onTap: onTap,
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        height: 1,
        color: outline.withValues(alpha: 0.65),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
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
    final colorScheme = Theme.of(context).colorScheme;
    final activeFg = colorScheme.onPrimary;
    final inactiveFg = colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: active ? activeFg : inactiveFg,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
