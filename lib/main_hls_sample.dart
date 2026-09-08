import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/scraper/hls_extractor_service.dart';

/// Standalone sample app demonstrating [HlsExtractorService].
///
/// Run with: `flutter run -t lib/main_hls_sample.dart` (Android/iOS recommended;
/// see the platform note on [HlsExtractorService]).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HlsSampleApp());
}

class HlsSampleApp extends StatelessWidget {
  const HlsSampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(title: 'HLS Extractor Sample', theme: ThemeData.dark(useMaterial3: true), home: const HlsSamplePage());
}

class HlsSamplePage extends StatefulWidget {
  const HlsSamplePage({super.key});

  @override
  State<HlsSamplePage> createState() => _HlsSamplePageState();
}

class _HlsSamplePageState extends State<HlsSamplePage> {
  final HlsExtractorService _extractor = HlsExtractorService();
  final TextEditingController _tmdbController = TextEditingController(text: '27205');
  final TextEditingController _seasonController = TextEditingController(text: '1');
  final TextEditingController _episodeController = TextEditingController(text: '1');

  String _type = 'movie';
  bool _running = false;
  Map<String, HlsExtractionResult> _results = <String, HlsExtractionResult>{};

  @override
  void dispose() {
    _tmdbController.dispose();
    _seasonController.dispose();
    _episodeController.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    final String tmdbId = _tmdbController.text.trim();
    if (tmdbId.isEmpty) return;

    setState(() {
      _running = true;
      _results = <String, HlsExtractionResult>{};
    });

    try {
      final Map<String, HlsExtractionResult> results = await _extractor.extractAll(
        tmdbId,
        type: _type,
        season: _type == 'tv' ? int.tryParse(_seasonController.text.trim()) : null,
        episode: _type == 'tv' ? int.tryParse(_episodeController.text.trim()) : null,
      );
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('HLS Extractor Sample')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _tmdbController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'TMDB id', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'movie', label: Text('Movie')),
                  ButtonSegment<String>(value: 'tv', label: Text('TV')),
                ],
                selected: <String>{_type},
                onSelectionChanged: (Set<String> value) => setState(() => _type = value.first),
              ),
            ],
          ),
          if (_type == 'tv') ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _seasonController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Season', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _episodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Episode', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? null : _extract,
            icon: _running ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
            label: Text(_running ? 'Extracting...' : 'Extract HLS'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No results yet.'))
                : ListView(
                    children: _results.entries.map((MapEntry<String, HlsExtractionResult> e) => _ResultTile(provider: e.key, result: e.value)).toList(),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.provider, required this.result});

  final String provider;
  final HlsExtractionResult result;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(result.success ? Icons.check_circle : Icons.error, color: result.success ? Colors.green : Colors.red),
      title: Text(Uri.parse(provider).host),
      subtitle: Text(result.success ? '${result.hlsUrl}\nsubtitles: ${result.subtitles.length}' : (result.error ?? 'Unknown error')),
      isThreeLine: result.success,
    ),
  );
}
