import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/player/infrastructure/local_server_preference.dart';
import 'package:popcorn_flutter/src/player/infrastructure/player_server_config.dart';
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
  bool? _localServer;
  bool _savingLocalServer = false;
  String? _localServerError;
  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _loadRegion();
    if (_isWindows) _loadLocalServer();
  }

  Future<void> _loadLocalServer() async {
    try {
      final enabled = await LocalServerPreference.isEnabled();
      if (mounted) setState(() => _localServer = enabled);
    } catch (error) {
      if (mounted) setState(() => _localServerError = error.toString());
    }
  }

  Future<void> _saveLocalServer(bool enabled) async {
    setState(() => _savingLocalServer = true);
    try {
      await LocalServerPreference.setEnabled(enabled);
      if (mounted) {
        setState(() {
          _localServer = enabled;
          _localServerError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _localServerError = error.toString());
    } finally {
      if (mounted) setState(() => _savingLocalServer = false);
    }
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
    showCountryPicker(
      context: context,
      favorite: [_region],
      // Windows has no flag emoji glyphs, so render flag images instead.
      customFlagBuilder: _isWindows
          ? (country) => _flagImage(country.countryCode, 28)
          : null,
      onSelect: (country) => _saveRegion(country.countryCode),
    );
  }

  Widget _flagImage(String code, double width) {
    return SizedBox(
      width: width,
      child: Image.network(
        'https://flagcdn.com/w80/${code.toLowerCase()}.png',
        width: width,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
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
    final regionValue =
        '${_isWindows ? '' : country?.flagEmoji ?? ''} $regionName${_usesDeviceRegion ? ' · ${ProfileTranslations.deviceRegion.trOf(context)}' : ''}';
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        children: [
          if (_isWindows)
            SwitchListTile(
              secondary: const Icon(Icons.computer),
              title: Text(ProfileTranslations.localPlayerServer.trOf(context)),
              subtitle: Text(
                PlayerServerConfig.usesDefinedServer
                    ? PlayerServerConfig.serverUrl
                    : _localServerError ??
                          ProfileTranslations.localPlayerServerHint.trOf(
                            context,
                          ),
              ),
              value:
                  PlayerServerConfig.usesDefinedServer ||
                  (_localServer ?? false),
              onChanged:
                  PlayerServerConfig.usesDefinedServer ||
                      _localServer == null ||
                      _savingLocalServer
                  ? null
                  : _saveLocalServer,
            ),
          ListTile(
            leading: _isWindows && country != null
                ? _flagImage(country.countryCode, 32)
                : const Icon(Icons.public),
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
      ),
    );
  }
}
