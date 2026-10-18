import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/profile/view/profile_translations.dart';
import 'package:popcorn_flutter/src/search/domain/media_region_preference.dart';

class AccountSettingsView extends StatefulWidget {
  const AccountSettingsView({super.key});

  @override
  State<AccountSettingsView> createState() => _AccountSettingsViewState();
}

class _AccountSettingsViewState extends State<AccountSettingsView> {
  String _region = MediaRegionPreference.deviceRegion;
  bool _usesDeviceRegion = true;

  @override
  void initState() {
    super.initState();
    _loadRegion();
  }

  Future<void> _loadRegion() async {
    final savedRegion = await MediaRegionPreference.savedRegion();
    if (!mounted) return;
    setState(() {
      _region = savedRegion ?? MediaRegionPreference.deviceRegion;
      _usesDeviceRegion = savedRegion == null;
    });
  }

  void _chooseRegion() {
    showCountryPicker(context: context, favorite: [_region], onSelect: (country) => _saveRegion(country.countryCode));
  }

  Future<void> _saveRegion(String? region) async {
    await MediaRegionPreference.setRegion(region);
    if (!mounted) return;
    setState(() {
      _region = region ?? MediaRegionPreference.deviceRegion;
      _usesDeviceRegion = region == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final country = Country.tryParse(_region);
    final regionName = country?.name ?? _region;
    final regionValue = '${country?.flagEmoji ?? ''} $regionName${_usesDeviceRegion ? ' · ${ProfileTranslations.deviceRegion.trOf(context)}' : ''}';
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.public),
          title: Text(ProfileTranslations.countryOrRegion.trOf(context)),
          subtitle: Text(regionValue),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_usesDeviceRegion)
                IconButton(
                  icon: const Icon(Icons.my_location_outlined),
                  tooltip: ProfileTranslations.useDeviceRegion.trOf(context),
                  onPressed: () => _saveRegion(null),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: _chooseRegion,
        ),
      ],
    );
  }
}
