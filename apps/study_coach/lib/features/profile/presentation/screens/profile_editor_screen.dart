import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import '../../../roadmap/domain/major_catalog.dart';
import '../../data/local/local_profile_avatar_store.dart';

class ProfileEditorScreen extends ConsumerStatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  ConsumerState<ProfileEditorScreen> createState() =>
      _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  bool _isSaving = false;
  String? _selectedAvatarId;
  /// Local major selection; when null, [UserProfileData.majorId] is used.
  String? _majorOverride;
  /// Local daily-study-minutes selection; null means "follow profile value".
  int? _dailyStudyMinutesOverride;
  bool _hasUserChangedDailyMinutes = false;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(currentAuthUserProvider).valueOrNull;
    final profileName = authUser?.displayName?.trim();
    final hasProfileName = profileName != null && profileName.isNotEmpty;
    final email = authUser?.email?.trim();
    final hasEmail = email != null && email.isNotEmpty;
    _usernameController = TextEditingController(
      text: hasProfileName
          ? profileName
          : (hasEmail ? email.split('@').first : ''),
    );
    if (authUser != null) {
      _selectedAvatarId =
          ref.read(localProfileAvatarIdProvider(authUser.uid)).valueOrNull;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _choosePresetAvatar(String avatarId) {
    setState(() {
      _selectedAvatarId = avatarId;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final authUser = ref.read(currentAuthUserProvider).valueOrNull;
    if (authUser == null || _isSaving) return;

    final strings = AppStrings.of(context);
    setState(() => _isSaving = true);
    try {
      final localAvatarStore = ref.read(localProfileAvatarStoreProvider);
      if (_selectedAvatarId != null) {
        await localAvatarStore.setSelectedAvatarId(
          uid: authUser.uid,
          avatarId: _selectedAvatarId!,
        );
      } else {
        await localAvatarStore.clearSelectedAvatarId(authUser.uid);
      }
      await ref.read(authRepositoryProvider).updateProfile(
            displayName: _usernameController.text,
          );
      final profile = ref.read(userProfileStreamProvider(authUser.uid)).valueOrNull;
      final majorToSave = _majorOverride ?? profile?.majorId;
      if (majorToSave != null && majorToSave.isNotEmpty) {
        await ref.read(userProfileRepositoryProvider).setMajor(
              uid: authUser.uid,
              majorId: majorToSave,
              source: 'profile_edit',
            );
      }
      if (_hasUserChangedDailyMinutes) {
        await ref.read(userProfileRepositoryProvider).setDailyStudyMinutes(
              uid: authUser.uid,
              minutes: _dailyStudyMinutesOverride,
            );
      }
      ref.invalidate(localProfileAvatarIdProvider(authUser.uid));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.profileUpdated)),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final details = e.toString().trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            details.isEmpty
                ? strings.couldNotUpdateProfile
                : '${strings.couldNotUpdateProfile} $details',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authUser = ref.watch(currentAuthUserProvider).valueOrNull;
    final profile = authUser == null
        ? null
        : ref.watch(userProfileStreamProvider(authUser.uid)).valueOrNull;
    final catalogMajorId = _catalogMajorId(
      _majorOverride ?? profile?.majorId,
    );
    final photoUrl = authUser?.photoUrl?.trim();
    final hasRemotePhoto = photoUrl != null && photoUrl.isNotEmpty;
    final savedAvatarId = authUser == null
        ? null
        : ref.watch(localProfileAvatarIdProvider(authUser.uid)).valueOrNull;
    final avatarId = _selectedAvatarId ?? savedAvatarId;
    final hasPresetAvatar = avatarId != null && avatarId.isNotEmpty;
    ImageProvider<Object>? imageProvider;
    if (!hasPresetAvatar && hasRemotePhoto) {
      imageProvider = NetworkImage(photoUrl);
    }
    final presetAvatarAsset = switch (avatarId) {
      LocalProfileAvatarStore.maleAvatarId => 'assets/avatars/male.svg',
      LocalProfileAvatarStore.femaleAvatarId => 'assets/avatars/female.svg',
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(strings.editProfile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: colorScheme.surfaceContainerHigh,
              backgroundImage: presetAvatarAsset == null ? imageProvider : null,
              child: presetAvatarAsset != null
                  ? ClipOval(
                      child: SvgPicture.asset(
                        presetAvatarAsset,
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                      ),
                    )
                  : imageProvider == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 54,
                          color: colorScheme.onSurfaceVariant,
                        )
                      : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.chooseAvatar,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AvatarOption(
                label: strings.avatarMale,
                assetPath: 'assets/avatars/male.svg',
                selected: avatarId == LocalProfileAvatarStore.maleAvatarId,
                onTap: _isSaving
                    ? null
                    : () => _choosePresetAvatar(
                        LocalProfileAvatarStore.maleAvatarId),
              ),
              const SizedBox(width: 16),
              _AvatarOption(
                label: strings.avatarFemale,
                assetPath: 'assets/avatars/female.svg',
                selected: avatarId == LocalProfileAvatarStore.femaleAvatarId,
                onTap: _isSaving
                    ? null
                    : () => _choosePresetAvatar(
                        LocalProfileAvatarStore.femaleAvatarId),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _usernameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: strings.username,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return strings.usernameRequired;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: authUser?.email ?? '',
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: strings.email,
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>(
                    _majorOverride ?? profile?.majorId,
                  ),
                  initialValue: catalogMajorId,
                  decoration: InputDecoration(
                    labelText: strings.major,
                    prefixIcon: const Icon(Icons.school_outlined),
                  ),
                  items: [
                    ...majorCatalog.map(
                      (major) => DropdownMenuItem<String>(
                        value: major.id,
                        child: Text(major.title),
                      ),
                    ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() => _majorOverride = value);
                        },
                ),
                const SizedBox(height: 16),
                _DailyStudyBudgetPicker(
                  enabled: !_isSaving,
                  selected: _hasUserChangedDailyMinutes
                      ? _dailyStudyMinutesOverride
                      : profile?.dailyStudyMinutes,
                  onChanged: (value) {
                    setState(() {
                      _dailyStudyMinutesOverride = value;
                      _hasUserChangedDailyMinutes = true;
                    });
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Text(strings.saveChanges),
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

String? _catalogMajorId(String? majorId) {
  if (majorId == null || majorId.isEmpty) return null;
  for (final m in majorCatalog) {
    if (m.id == majorId) return majorId;
  }
  return null;
}

class _DailyStudyBudgetPicker extends StatelessWidget {
  const _DailyStudyBudgetPicker({
    required this.enabled,
    required this.selected,
    required this.onChanged,
  });

  /// Stop showing arbitrary spinners; pre-set chips that map to common study sessions.
  static const List<int> _options = [30, 60, 90, 120, 180, 240];

  final bool enabled;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeValue = selected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.dailyStudyBudgetTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (activeValue != null)
                TextButton(
                  onPressed: enabled ? () => onChanged(null) : null,
                  child: Text(strings.clearExamDate),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            strings.dailyStudyBudgetHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.map((minutes) {
              final isSelected = activeValue == minutes;
              return ChoiceChip(
                label: Text(strings.dailyStudyBudgetValue(minutes)),
                selected: isSelected,
                onSelected: enabled
                    ? (picked) => onChanged(picked ? minutes : null)
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.label,
    required this.assetPath,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    selected ? colorScheme.primary : colorScheme.outlineVariant,
                width: selected ? 2.5 : 1.2,
              ),
            ),
            child: ClipOval(
              child: SvgPicture.asset(
                assetPath,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
