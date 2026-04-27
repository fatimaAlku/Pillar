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
    final majorTitle = majorTitleFromId(profile?.majorId).trim();
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
                TextFormField(
                  initialValue: majorTitle.isEmpty ? '-' : majorTitle,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: strings.major,
                    prefixIcon: const Icon(Icons.school_outlined),
                  ),
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
