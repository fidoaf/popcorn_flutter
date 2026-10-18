import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/home/view/home_translations.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_channel.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_controller.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_logo.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_programme.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/player/player.dart';

class LiveTvPage extends StatefulWidget {
  const LiveTvPage({super.key, required this.channelId, this.channel, this.watch = false, this.controller});

  final String channelId;
  final LiveTvChannel? channel;
  final bool watch;
  final LiveTvController? controller;

  @override
  State<LiveTvPage> createState() => _LiveTvPageState();
}

class _LiveTvPageState extends State<LiveTvPage> {
  late final LiveTvController _controller;
  LiveTvChannel? _channel;
  late Future<List<LiveTvProgramme>> _programmes;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? LiveTvController();
    _channel = widget.channel;
    if (_channel == null) {
      _loadChannel();
    } else if (!widget.watch) {
      _programmes = _controller.loadProgrammes(widget.channelId);
    }
  }

  Future<void> _loadChannel() async {
    setState(() { _loading = true; _failed = false; });
    await _controller.load(channelId: widget.channelId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = _controller.hasError;
      _channel = _controller.channels.where((entry) => entry.id == widget.channelId).firstOrNull;
      if (_channel != null && !widget.watch) _programmes = _controller.loadProgrammes(widget.channelId);
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) { context.pop(); } else { context.go(AppRoutes.home); }
  }

  @override
  Widget build(BuildContext context) {
    final channel = _channel;
    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0F171E)),
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: Text(channel?.name ?? HomeTranslations.liveTv.trOf(context)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : channel == null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text((_failed ? HomeTranslations.liveTvUnavailable : HomeTranslations.noLiveChannels).trOf(context)),
                TextButton(onPressed: _loadChannel, child: Text(HomeTranslations.retry.trOf(context))),
              ]))
            : widget.watch
            ? VideoPlayerFactory.create(source: MediaSource(url: channel.streamUrl, headers: channel.headers), engine: VideoPlayerEngine.mediaKit)
            : _details(channel),
      ),
    );
  }

  Widget _details(LiveTvChannel channel) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: 180, child: LiveTvLogo(channel: channel)),
        const SizedBox(height: 20),
        Text(channel.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text([channel.country, channel.network, channel.feed, ...channel.categories, ...channel.languages].where((value) => value.isNotEmpty).join(' · ')),
        if (channel.website != null) Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText(channel.website.toString())),
        if (channel.broadcastAreas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${HomeTranslations.broadcastArea.trOf(context)}: '
                  '${channel.broadcastAreas.map((area) => area.localizedName(Localizations.localeOf(context))).join(', ')}',
                ),
                Text(HomeTranslations.broadcastAreaInfo.trOf(context), style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        if (channel.isGeoBlocked)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.public_off, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.country.isNotEmpty
                            ? HomeTranslations.geoRestrictedCountry
                                  .trOf(context)
                                  .replaceAll('{country}', channel.localizedCountry(Localizations.localeOf(context)))
                            : HomeTranslations.geoRestrictedInfo.trOf(context),
                        style: const TextStyle(color: Colors.amber),
                      ),
                      Text(
                        (channel.country.isNotEmpty ? HomeTranslations.geoRestrictedCountryInfo : HomeTranslations.exactGeoRestrictionsUnknown)
                            .trOf(context),
                        style: const TextStyle(color: Colors.amber),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.liveTvWatch(channel.id), extra: channel),
            icon: const Icon(Icons.play_arrow),
            label: Text(HomeTranslations.play.trOf(context)),
          ),
        ),
        const SizedBox(height: 32),
        Text(HomeTranslations.epg.trOf(context), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FutureBuilder<List<LiveTvProgramme>>(
          future: _programmes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(HomeTranslations.epgError.trOf(context)),
                TextButton(
                  onPressed: () => setState(() {
                    _programmes = _controller.loadProgrammes(channel.id);
                  }),
                  child: Text(HomeTranslations.retry.trOf(context)),
                ),
              ]);
            }
            final programmes = snapshot.data!;
            if (programmes.isEmpty) return Text(HomeTranslations.epgEmpty.trOf(context));
            final locale = Localizations.localeOf(context).toLanguageTag();
            final now = DateTime.now();
            return Column(
              children: programmes.map((programme) {
                final start = programme.start.toLocal();
                final end = programme.end.toLocal();
                final live = !now.isBefore(programme.start) && now.isBefore(programme.end);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${DateFormat.MMMd(locale).format(start)}  ${DateFormat.Hm(locale).format(start)} – ${DateFormat.Hm(locale).format(end)}'),
                        if (live) Text(HomeTranslations.liveLabel.trOf(context), style: const TextStyle(color: Colors.redAccent)),
                        Text(programme.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        if (programme.description.isNotEmpty) Text(programme.description),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
