import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/home/view/home_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/radio/radio_controller.dart';
import 'package:popcorn_flutter/src/radio/radio_logo.dart';
import 'package:popcorn_flutter/src/radio/radio_station.dart';
import 'package:popcorn_flutter/src/radio/radio_translations.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key, required this.stationId, this.station, this.controller, this.createPlayer});

  final String stationId;
  final RadioStation? station;
  final RadioController? controller;
  final Player Function()? createPlayer;

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  late final RadioController _controller;
  RadioStation? _station;
  Player? _player;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _loading = false;
  bool _busy = false;
  bool _playing = false;
  bool _buffering = false;
  bool _opened = false;
  bool _playbackFailed = false;
  double _volume = 100;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? RadioController();
    _station = widget.station;
    if (_station == null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _controller.load(stationId: widget.stationId);
    if (!mounted) return;
    setState(() {
      _station = _controller.stations.where((station) => station.id == widget.stationId).firstOrNull;
      _loading = false;
    });
  }

  void _playbackError(Object error) {
    debugPrint('Unable to play radio station ${widget.stationId}: $error');
    if (!mounted) return;
    setState(() {
      _playbackFailed = true;
      _opened = false;
      _playing = false;
      _buffering = false;
    });
  }

  Future<void> _togglePlayback() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _playbackFailed = false;
    });
    try {
      final player = _player;
      if (player != null && _opened) {
        if (_playing) {
          await player.pause();
        } else {
          await player.play();
        }
      } else {
        final url = await _controller.startPlayback(widget.stationId);
        if (!mounted) return;
        final audio = _player ??= widget.createPlayer?.call() ?? Player();
        if (_subscriptions.isEmpty) {
          _subscriptions.addAll([
            audio.stream.playing.listen((playing) {
              if (mounted) setState(() => _playing = playing);
            }),
            audio.stream.buffering.listen((buffering) {
              if (mounted) setState(() => _buffering = buffering);
            }),
            audio.stream.error.listen(_playbackError),
          ]);
        }
        await audio.open(Media(url.toString()), play: true);
        if (mounted && !_playbackFailed) _opened = true;
      }
    } catch (error) {
      _playbackError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setVolume(double value) async {
    setState(() => _volume = value);
    try {
      await _player?.setVolume(value);
    } catch (error) {
      _playbackError(error);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    final player = _player;
    if (player != null) unawaited(player.dispose());
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final station = _station;
    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0F171E)),
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          title: Text(station?.name ?? RadioTranslations.title.trOf(context)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : station == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text((_controller.hasError ? RadioTranslations.unavailable : RadioTranslations.empty).trOf(context)),
                    TextButton(onPressed: _load, child: Text(HomeTranslations.retry.trOf(context))),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(height: 180, child: RadioLogo(station: station)),
                  const SizedBox(height: 20),
                  Text(station.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text([station.country, ...station.languages, ...station.tags.take(4)].where((value) => value.isNotEmpty).join(' · ')),
                  Text([station.codec, if (station.bitrate > 0) '${station.bitrate} kbps'].where((value) => value.isNotEmpty).join(' · ')),
                  const SizedBox(height: 24),
                  if (_playbackFailed) Text(RadioTranslations.playbackError.trOf(context), style: const TextStyle(color: Colors.amber)),
                  if (_busy || _buffering) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _togglePlayback,
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      label: Text((_playing ? RadioTranslations.pause : HomeTranslations.play).trOf(context)),
                    ),
                  ),
                  if (_player != null)
                    Row(
                      children: [
                        const Icon(Icons.volume_up),
                        Expanded(
                          child: Slider(value: _volume, min: 0, max: 100, label: RadioTranslations.volume.trOf(context), onChanged: _setVolume),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Text(RadioTranslations.attribution.trOf(context), style: const TextStyle(color: Colors.white70)),
                ],
              ),
      ),
    );
  }
}
