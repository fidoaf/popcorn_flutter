import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/player/infrastructure/player_server_config.dart';
import 'package:popcorn_flutter/src/profile/view/profile_translations.dart';

class PlayerSettingsView extends StatefulWidget {
  const PlayerSettingsView({super.key, this.endpoint, this.token, this.client, this.backgroundColor});

  final Uri? endpoint;
  final String? token;
  final http.Client? client;
  final Color? backgroundColor;

  @override
  State<PlayerSettingsView> createState() => _PlayerSettingsViewState();
}

class _PlayerSettingsViewState extends State<PlayerSettingsView> {
  Map<String, dynamic>? _settings;
  final _formKey = GlobalKey<FormState>();
  int _revision = 0;
  late final Uri _endpoint = widget.endpoint ?? Uri.parse(PlayerServerConfig.serverUrl).replace(path: '/settings');
  late final String _token = widget.token ?? PlayerServerConfig.token;
  late final http.Client _client = widget.client ?? http.Client();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Map<String, String> get _headers => {if (_token.isNotEmpty) 'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'};

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _client.get(_endpoint, headers: _headers);
      if (response.statusCode != 200) {
        throw FormatException(_responseError(response));
      }
      final settings = _parseSettings(response.body);
      if (!mounted) return;
      _settings = settings;
      _revision++;
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_saving || _settings == null || !_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final settings = _settings!;
      final names = <String>{};
      for (final provider in settings['providers'] as List) {
        final name = provider['name']?.toString().trim() ?? '';
        final host = provider['host']?.toString().trim() ?? '';
        if (name.isEmpty || host.isEmpty || !names.add(name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), ''))) {
          throw FormatException(
            _text(
              'Each provider needs a unique name and a host.',
              'Cada proveedor necesita un nombre único y un servidor.',
              'Cada proveïdor necessita un nom únic i un servidor.',
            ),
          );
        }
      }
      final response = await _client.put(_endpoint, headers: _headers, body: jsonEncode(settings));
      if (response.statusCode != 200) {
        throw FormatException(_responseError(response));
      }
      if (!mounted) return;
      _settings = _parseSettings(response.body);
      _revision++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ProfileTranslations.playerSettingsSaved.trOf(context))));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _parseSettings(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Settings must be a JSON object.');
    }
    final providers = value['providers'];
    if (providers is! List || providers.isEmpty || providers.any((provider) => provider is! Map<String, dynamic>)) {
      throw const FormatException('Settings must contain a list of providers.');
    }
    return value;
  }

  String _text(String english, String spanish, String catalan) =>
      Translation({AppLanguage.en: english, AppLanguage.es: spanish, AppLanguage.ca: catalan}).trOf(context);

  Widget _valueEditor(String label, dynamic value, ValueChanged<dynamic> onChanged, {Key? key}) {
    if (value is bool) {
      return SwitchListTile(key: key, contentPadding: EdgeInsets.zero, title: Text(label), value: value, onChanged: _saving ? null : onChanged);
    }
    if (value is Map || value is List) {
      final isMap = value is Map;
      final entries = isMap
          ? value.entries.map((entry) => MapEntry<dynamic, dynamic>(entry.key, entry.value)).toList()
          : List.generate(value.length as int, (index) => MapEntry<dynamic, dynamic>(index, value[index]));
      return ExpansionTile(
        key: key,
        tilePadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text('${entries.length}'),
        children: [
          for (final entry in entries)
            Padding(
              key: ValueKey('${entry.key}-${entries.length}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (isMap)
                          TextFormField(
                            initialValue: entry.key.toString(),
                            enabled: !_saving,
                            decoration: InputDecoration(labelText: _text('Key', 'Clave', 'Clau')),
                            validator: (text) => text == null || text.trim().isEmpty || (text != entry.key && value.containsKey(text))
                                ? _text('Enter a unique key', 'Introduce una clave única', 'Introdueix una clau única')
                                : null,
                            onSaved: (text) {
                              if (text == entry.key) return;
                              final currentValue = value.remove(entry.key);
                              value[text!] = currentValue;
                              onChanged(value);
                            },
                          ),
                        _valueEditor(isMap ? _text('Value', 'Valor', 'Valor') : '${entry.key + 1}', entry.value, (updated) {
                          value[entry.key] = updated;
                          onChanged(value);
                        }),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _text('Remove', 'Eliminar', 'Elimina'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            if (isMap) {
                              value.remove(entry.key);
                            } else {
                              value.removeAt(entry.key as int);
                            }
                            onChanged(value);
                          }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: _text('Add entry', 'Añadir entrada', 'Afegeix una entrada'),
              icon: const Icon(Icons.add),
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      if (isMap) {
                        var name = 'key';
                        while (value.containsKey(name)) {
                          name += '_';
                        }
                        value[name] = '';
                      } else {
                        value.add(<String, dynamic>{'name': '', 'value': ''});
                      }
                      onChanged(value);
                    }),
            ),
          ),
        ],
      );
    }
    final choices = switch (label) {
      'scheme' => ['https', 'http'],
      'method' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'],
      'strategy' => ['redirect'],
      _ => <String>[],
    };
    if (choices.contains(value)) {
      return DropdownButtonFormField<String>(
        key: key,
        initialValue: value as String,
        decoration: InputDecoration(labelText: label),
        items: choices.map((choice) => DropdownMenuItem(value: choice, child: Text(choice))).toList(),
        onChanged: _saving ? null : onChanged,
      );
    }
    return TextFormField(
      key: key,
      initialValue: value?.toString() ?? '',
      enabled: !_saving,
      decoration: InputDecoration(labelText: label),
      keyboardType: value is num ? TextInputType.number : TextInputType.text,
      validator: (text) {
        if ((label == 'name' || label == 'host') && (text == null || text.trim().isEmpty)) {
          return _text('Required', 'Obligatorio', 'Obligatori');
        }
        if (value is num && num.tryParse(text ?? '') == null) {
          return _text('Enter a number', 'Introduce un número', 'Introdueix un nombre');
        }
        return null;
      },
      onChanged: (text) => onChanged(value is num ? num.tryParse(text) ?? value : text),
    );
  }

  Widget _providerForm() {
    final providers = (_settings!['providers'] as List).cast<Map<String, dynamic>>();
    final names = providers.map((provider) => provider['name']?.toString() ?? '').toSet();
    return Form(
      key: _formKey,
      child: ListView(
        key: ValueKey(_revision),
        padding: const EdgeInsets.all(16),
        children: [
          Text(_endpoint.origin, style: Theme.of(context).textTheme.bodySmall),
          if (_error != null)
            Text(
              _error!,
              key: const ValueKey('player-settings-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('default-${_settings!['initialProvider']}'),
            initialValue: names.contains(_settings!['initialProvider']) ? _settings!['initialProvider'] as String : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: _text('Default provider', 'Proveedor predeterminado', 'Proveïdor predeterminat')),
            items: names.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
            onChanged: _saving ? null : (name) => _settings!['initialProvider'] = name,
          ),
          const SizedBox(height: 16),
          for (final provider in providers)
            Card(
              key: ObjectKey(provider),
              color: widget.backgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                maintainState: true,
                initiallyExpanded: provider['host'] == '',
                title: Text(provider['name']?.toString() ?? ''),
                subtitle: Text(provider['host']?.toString() ?? ''),
                trailing: IconButton(
                  tooltip: _text('Remove provider', 'Eliminar proveedor', 'Elimina el proveïdor'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _saving || providers.length <= 1
                      ? null
                      : () => setState(() {
                          (_settings!['providers'] as List).remove(provider);
                          if (_settings!['initialProvider'] == provider['name']) {
                            _settings!['initialProvider'] = providers.firstWhere((other) => other != provider)['name'];
                          }
                        }),
                ),
                children: [
                  for (final entry in provider.entries.toList())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                      child: _valueEditor(entry.key, entry.value, (value) {
                        if (entry.key == 'name') {
                          if (_settings!['initialProvider'] == provider['name']) _settings!['initialProvider'] = value;
                        }
                        provider[entry.key] = value;
                      }, key: ValueKey('provider-${providers.indexOf(provider)}-${entry.key}')),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(_text('Add provider', 'Añadir proveedor', 'Afegeix un proveïdor')),
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      var name = 'Provider';
                      while (names.contains(name)) {
                        name += '_';
                      }
                      (_settings!['providers'] as List).add(<String, dynamic>{
                        'name': name,
                        'scheme': 'https',
                        'host': '',
                        'path': '/embed/{type}/{id}',
                        'method': 'GET',
                        'parameters': <String, dynamic>{},
                        'headers': <String, dynamic>{},
                        'cookies': <dynamic>[],
                        'sandbox': false,
                      });
                    }),
            ),
          ),
        ],
      ),
    );
  }

  String _responseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) return body['error'] as String;
    } catch (_) {
      // Use the status code when the server response is not JSON.
    }
    return 'Request failed (${response.statusCode}).';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.backgroundColor,
        surfaceTintColor: widget.backgroundColor == null ? null : Colors.transparent,
        title: Text(ProfileTranslations.playerSettings.trOf(context)),
        actions: [
          IconButton(
            tooltip: ProfileTranslations.playerSettingsReload.trOf(context),
            onPressed: _loading || _saving ? null : _loadSettings,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: const ValueKey('player-settings-save'),
            tooltip: ProfileTranslations.playerSettingsSave.trOf(context),
            onPressed: _loading || _saving || _settings == null ? null : _saveSettings,
            icon: _saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _settings != null
          ? _providerForm()
          : Center(child: Text(_error ?? '', key: const ValueKey('player-settings-error'))),
    );
  }
}
