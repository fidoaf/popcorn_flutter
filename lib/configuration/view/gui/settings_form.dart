import 'package:flutter/material.dart';
import 'package:popcorn_flutter/app/core/service_locator.dart';

class ApplicationSettings extends StatefulWidget {
  const ApplicationSettings({super.key});

  @override
  State<StatefulWidget> createState() => _ApplicationSettingsState();
}

class _ApplicationSettingsState extends State<ApplicationSettings> {
  String? omdbKey;

  @override
  void initState() {
    //
    final config = ServiceLocator.configuration;
    omdbKey = config.omdbKeySecret;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Search', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 30),
            const Text('OMDb API key'),
            TextFormField(
              initialValue: omdbKey,
              obscureText: true,
              obscuringCharacter: '*',
            ),
          ],
        ),
      ),
    );
  }
}
