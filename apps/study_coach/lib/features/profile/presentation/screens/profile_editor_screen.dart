import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';

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
  PlatformFile? _selectedImage;
  bool _removePhoto = false;

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
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final selected = result.files.single;
    final hasPath = selected.path != null && selected.path!.isNotEmpty;
    final hasBytes = selected.bytes != null && selected.bytes!.isNotEmpty;
    if (!hasPath && !hasBytes) return;
    setState(() {
      _selectedImage = selected;
      _removePhoto = false;
    });
  }

  void _removePhotoSelection() {
    setState(() {
      _selectedImage = null;
      _removePhoto = true;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final authUser = ref.read(currentAuthUserProvider).valueOrNull;
    if (authUser == null || _isSaving) return;

    final strings = AppStrings.of(context);
    setState(() => _isSaving = true);
    try {
      String? uploadedPhotoUrl;
      if (_selectedImage != null) {
        uploadedPhotoUrl =
            await ref.read(authRepositoryProvider).uploadProfilePhoto(
                  uid: authUser.uid,
                  filePath: _selectedImage!.path,
                  fileBytes: _selectedImage!.bytes,
                  fileName: _selectedImage!.name,
                );
      }
      await ref.read(authRepositoryProvider).updateProfile(
            displayName: _usernameController.text,
            photoUrl: _removePhoto ? '' : uploadedPhotoUrl,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.profileUpdated)),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final details = switch (e.code) {
        'object-not-found' =>
          '${strings.couldNotUpdateProfile} Uploaded image could not be read back from Storage. Check Storage rules for authenticated read/write access.',
        'unauthorized' =>
          '${strings.couldNotUpdateProfile} Storage permission denied. Check Firebase Storage rules.',
        _ => (() {
            final message = e.message?.trim();
            return message != null && message.isNotEmpty
                ? '${strings.couldNotUpdateProfile} $message'
                : strings.couldNotUpdateProfile;
          })(),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(details)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotUpdateProfile)),
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
    final photoUrl = authUser?.photoUrl?.trim();
    final hasRemotePhoto = photoUrl != null && photoUrl.isNotEmpty;
    final canRemovePhoto = _selectedImage != null || hasRemotePhoto;
    ImageProvider<Object>? imageProvider;
    if (_selectedImage != null && !_removePhoto) {
      if (_selectedImage!.bytes != null && _selectedImage!.bytes!.isNotEmpty) {
        imageProvider = MemoryImage(_selectedImage!.bytes!);
      } else if (_selectedImage!.path != null &&
          _selectedImage!.path!.isNotEmpty) {
        imageProvider = FileImage(File(_selectedImage!.path!));
      }
    } else if (hasRemotePhoto && !_removePhoto) {
      imageProvider = NetworkImage(photoUrl);
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.editProfile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: colorScheme.surfaceContainerHigh,
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Icon(
                      Icons.person_rounded,
                      size: 54,
                      color: colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _isSaving ? null : _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(strings.changePhoto),
            ),
          ),
          Center(
            child: TextButton(
              onPressed:
                  (_isSaving || !canRemovePhoto) ? null : _removePhotoSelection,
              child: Text(strings.removePhoto),
            ),
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
