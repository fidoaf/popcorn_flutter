import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/profile/domain/home_section.dart';
import 'package:popcorn_flutter/src/profile/domain/profile.dart';
import 'package:popcorn_flutter/src/profile/view/avatar_crop_dialog.dart';
import 'package:popcorn_flutter/src/profile/view/profile_avatar.dart';
import 'package:popcorn_flutter/src/profile/view/profile_controller.dart';
import 'package:popcorn_flutter/src/profile/view/profile_translations.dart';

class ProfileSettingsView extends StatefulWidget {
  const ProfileSettingsView({
    super.key,
    required this.profileController,
    this.profileId,
  });

  final ProfileController profileController;
  final String? profileId;

  @override
  State<ProfileSettingsView> createState() => _ProfileSettingsViewState();
}

class _ProfileSettingsViewState extends State<ProfileSettingsView> {
  bool _saving = false;
  bool _savingName = false;
  bool _uploadingAvatar = false;
  String? _error;
  late final TextEditingController _nameController = TextEditingController();
  String? _editedProfileId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Profile? _profile(ProfileController controller) {
    final id = widget.profileId ?? controller.activeProfileId;
    if (id == null) return null;
    for (final profile in controller.profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  Future<void> _saveName(Profile profile) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == profile.displayName) return;
    setState(() {
      _savingName = true;
      _error = null;
    });
    try {
      await widget.profileController.rename(profile.id, name);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changeAvatar(Profile profile) async {
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final image = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await showAvatarCropDialog(context, image);
    if (cropped == null) return;
    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      await widget.profileController.changeAvatar(
        profile.id,
        cropped,
        fileExtension: 'png',
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _setHomeSection(HomeSection section, bool enabled) async {
    final controller = widget.profileController;
    final profile = _profile(controller);
    if (profile == null) return;
    final sections = profile.homeSections?.toSet() ?? <HomeSection>{};
    if (enabled) {
      sections.add(section);
    } else {
      sections.remove(section);
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await controller.setHomeSections(
        profile.id,
        HomeSection.values.where(sections.contains).toList(growable: false),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(HomeSection section, BuildContext context) => switch (section) {
    HomeSection.movies => ProfileTranslations.homeSectionMovies.trOf(context),
    HomeSection.tvSeries => ProfileTranslations.homeSectionTvSeries.trOf(
      context,
    ),
    HomeSection.trailers => ProfileTranslations.homeSectionTrailers.trOf(
      context,
    ),
    HomeSection.liveTv => ProfileTranslations.homeSectionLiveTv.trOf(context),
    HomeSection.liveRadio => ProfileTranslations.homeSectionLiveRadio.trOf(
      context,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: widget.profileController,
        builder: (context, _) {
          final controller = widget.profileController;
          final profile = _profile(controller);
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profile == null) {
            return Center(
              child: Text(
                ProfileTranslations.profileHomeSettingsUnavailable.trOf(
                  context,
                ),
              ),
            );
          }
          if (_editedProfileId != profile.id) {
            _editedProfileId = profile.id;
            _nameController.text = profile.displayName;
          }
          final selected =
              profile.homeSections?.toSet() ?? const <HomeSection>{};
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  ProfileTranslations.editProfile.trOf(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ProfileAvatar(
                      url: profile.avatarUrl,
                      initial: profile.displayName.trim().isEmpty
                          ? '?'
                          : profile.displayName.trim()[0].toUpperCase(),
                      size: 96,
                    ),
                    IconButton.filled(
                      tooltip: ProfileTranslations.changePicture.trOf(context),
                      onPressed: _uploadingAvatar || _savingName
                          ? null
                          : () => _changeAvatar(profile),
                      icon: _uploadingAvatar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: ProfileTranslations.profileName.trOf(context),
                    suffixIcon: IconButton(
                      tooltip: ProfileTranslations.save.trOf(context),
                      onPressed: _savingName ? null : () => _saveName(profile),
                      icon: _savingName
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                    ),
                  ),
                  onSubmitted: (_) => _saveName(profile),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  ProfileTranslations.homeSectionsHint.trOf(context),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final section in HomeSection.values)
                SwitchListTile.adaptive(
                  title: Text(_label(section, context)),
                  value: selected.contains(section),
                  onChanged: _saving
                      ? null
                      : (enabled) => _setHomeSection(section, enabled),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${ProfileTranslations.saveHomeSectionsError.trOf(context)}: $_error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
