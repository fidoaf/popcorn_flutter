import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/profile/domain/profile.dart';
import 'package:popcorn_flutter/src/profile/view/avatar_crop_dialog.dart';
import 'package:popcorn_flutter/src/profile/view/profile_avatar.dart';
import 'package:popcorn_flutter/src/profile/view/profile_controller.dart';
import 'package:popcorn_flutter/src/profile/view/profile_translations.dart';

/// Opens the profile switcher: pick a profile, add one, edit the active one, or
/// sign out.
Future<void> showProfileSheet(BuildContext context, {required ProfileController profileController, required AuthController authController}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ProfileSheet(profileController: profileController, authController: authController),
  );
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.profileController, required this.authController});

  final ProfileController profileController;
  final AuthController authController;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  String? _switchingId;

  Future<void> _switchTo(String profileId) async {
    if (_switchingId != null) return;
    setState(() => _switchingId = profileId);
    await widget.profileController.switchTo(profileId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileController = widget.profileController;
    return SafeArea(
      child: AnimatedBuilder(
        animation: profileController,
        builder: (context, _) {
          final activeId = profileController.activeProfileId;
          final switching = _switchingId != null;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(ProfileTranslations.whosWatching.trOf(context), style: Theme.of(context).textTheme.titleLarge),
                ),
                for (final profile in profileController.profiles)
                  ListTile(
                    enabled: !switching,
                    leading: ProfileAvatar(url: profile.avatarUrl, initial: _initialOf(profile), size: 36),
                    title: Text(profile.displayName),
                    trailing: _switchingId == profile.id
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : profile.id == activeId
                        ? const Icon(Icons.check_circle, color: Colors.deepOrange)
                        : IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: ProfileTranslations.editProfile.trOf(context),
                            onPressed: switching ? null : () => showProfileEditDialog(context, profileController: profileController, profile: profile),
                          ),
                    onTap: switching ? null : () => _switchTo(profile.id),
                  ),
                ListTile(
                  enabled: !switching,
                  leading: const CircleAvatar(radius: 18, child: Icon(Icons.add)),
                  title: Text(ProfileTranslations.addProfile.trOf(context)),
                  onTap: switching ? null : () => showProfileEditDialog(context, profileController: profileController),
                ),
                const Divider(height: 8),
                ListTile(
                  enabled: !switching,
                  leading: const Icon(Icons.logout),
                  title: Text(ProfileTranslations.signOut.trOf(context)),
                  onTap: switching
                      ? null
                      : () async {
                          await widget.authController.signOut();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Opens the create/edit dialog. When [profile] is `null`, a new profile is
/// created; otherwise [profile] is edited (rename and/or change picture).
Future<void> showProfileEditDialog(BuildContext context, {required ProfileController profileController, Profile? profile}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ProfileEditDialog(profileController: profileController, profile: profile),
  );
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.profileController, this.profile});

  final ProfileController profileController;
  final Profile? profile;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.profile?.displayName ?? '');
  bool _busy = false;
  bool _uploadingPhoto = false;
  Uint8List? _pendingBytes;

  bool get _isEditing => widget.profile != null;
  bool get _locked => _busy || _uploadingPhoto;

  // The freshest copy of the edited profile, reflecting an avatar just uploaded.
  Profile? get _current {
    final id = widget.profile?.id;
    if (id == null) return null;
    final match = widget.profileController.profiles.where((profile) => profile.id == id);
    return match.isNotEmpty ? match.first : widget.profile;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _changePicture() async {
    final profile = widget.profile;
    if (profile == null) return;
    const typeGroup = XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final picked = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await showAvatarCropDialog(context, picked);
    if (cropped == null) return;
    // Show the cropped image with a spinner overlay while it uploads.
    setState(() {
      _pendingBytes = cropped;
      _uploadingPhoto = true;
    });
    try {
      // cropCircle() always outputs PNG.
      await widget.profileController.changeAvatar(profile.id, cropped, fileExtension: 'png');
    } catch (_) {
      if (mounted) setState(() => _uploadingPhoto = false);
      return;
    }
    // Close the editor once the new picture is saved.
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (_isEditing) {
        await widget.profileController.rename(widget.profile!.id, name);
      } else {
        await widget.profileController.addProfile(name);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _avatarPreview() {
    const size = 72.0;
    final pending = _pendingBytes;
    final Widget avatar = pending != null
        ? ClipOval(
            child: Image.memory(pending, width: size, height: size, fit: BoxFit.cover),
          )
        : ProfileAvatar(url: _current?.avatarUrl, initial: _initialOf(_current ?? widget.profile!), size: size);
    return Stack(
      alignment: Alignment.center,
      children: [
        avatar,
        if (_uploadingPhoto)
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
            child: const Center(
              child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? ProfileTranslations.editProfile : ProfileTranslations.newProfile;
    return AlertDialog(
      title: Text(title.trOf(context)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isEditing) ...[_avatarPreview(), const SizedBox(height: 16)],
          TextField(
            controller: _name,
            autofocus: true,
            enabled: !_locked,
            decoration: InputDecoration(labelText: ProfileTranslations.profileName.trOf(context)),
            onSubmitted: (_) => _submit(),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _locked ? null : _changePicture,
              icon: const Icon(Icons.image_outlined),
              label: Text(ProfileTranslations.changePicture.trOf(context)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _locked ? null : () => Navigator.of(context).pop(), child: Text(ProfileTranslations.cancel.trOf(context))),
        FilledButton(
          onPressed: _locked ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text((_isEditing ? ProfileTranslations.save : ProfileTranslations.create).trOf(context)),
        ),
      ],
    );
  }
}

String _initialOf(Profile profile) {
  final name = profile.displayName.trim();
  return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
}
