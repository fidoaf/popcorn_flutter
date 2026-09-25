import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:popcorn_flutter/src/player/domain/fullscreen_controller.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/resume_store.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/stream_racer.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/stream_resolver.dart';

/// A native [VideoPlayer] built on `media_kit`, offering an alternative to the
/// WebView-based player.
///
/// It plays the [source] stream directly (HLS or progressive) with a custom
/// control surface and replicates the reference HTML player's behaviour:
/// fastest-source racing across [alternates], resume-from-position prompts, and
/// quality/audio/subtitle track selection.
final class MediaKitVideoPlayer extends VideoPlayer {
  const MediaKitVideoPlayer({super.key, required super.source, required this.fullscreenController, this.alternates = const <Uri>[], super.onUrlChanged});

  final FullscreenController fullscreenController;

  /// Additional stream URLs to race against [source] before playback; the
  /// fastest validated candidate wins. Empty means "play [source] directly".
  final List<Uri> alternates;

  @override
  Widget build(BuildContext context) =>
      _MediaKitPlayer(source: source, fullscreenController: fullscreenController, alternates: alternates, onUrlChanged: onUrlChanged);
}

class _MediaKitPlayer extends StatefulWidget {
  const _MediaKitPlayer({required this.source, required this.fullscreenController, required this.alternates, this.onUrlChanged});

  final MediaSource source;
  final FullscreenController fullscreenController;
  final List<Uri> alternates;
  final ValueChanged<Uri>? onUrlChanged;

  @override
  State<_MediaKitPlayer> createState() => _MediaKitPlayerState();
}

class _MediaKitPlayerState extends State<_MediaKitPlayer> {
  static bool _mediaKitReady = false;

  late final Player _player;
  late final VideoController _controller;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  bool _controlsVisible = true;
  Timer? _hideTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  bool _playing = false;
  bool _buffering = true;
  double _volume = 1;
  bool _muted = false;
  double? _scrubTarget;

  Tracks _tracks = const Tracks();
  Track _selected = const Track();

  Duration _lastSaved = Duration.zero;
  Duration? _resumeAt;
  Timer? _resumeCountdown;
  int _resumeSecondsLeft = 8;

  String get _resumeId => widget.source.url.toString();

  @override
  void initState() {
    super.initState();
    if (!_mediaKitReady) {
      MediaKit.ensureInitialized();
      _mediaKitReady = true;
    }
    _player = Player();
    _controller = VideoController(_player);
    _wireStreams();
    _startPlayback();
    _scheduleHide();
  }

  void _wireStreams() {
    final stream = _player.stream;
    _subscriptions.addAll([
      stream.position.listen((value) {
        if (_scrubTarget != null) return;
        setState(() => _position = value);
        _maybeSavePosition(value);
      }),
      stream.duration.listen((value) => setState(() => _duration = value)),
      stream.buffer.listen((value) => setState(() => _buffer = value)),
      stream.playing.listen((value) => setState(() => _playing = value)),
      stream.buffering.listen((value) => setState(() => _buffering = value)),
      stream.volume.listen(
        (value) => setState(() {
          _volume = (value / 100).clamp(0, 1);
          _muted = value == 0;
        }),
      ),
      stream.tracks.listen((value) => setState(() => _tracks = value)),
      stream.track.listen((value) => setState(() => _selected = value)),
      stream.completed.listen((done) {
        if (done) ResumeStore.clear(_resumeId);
      }),
    ]);
  }

  Future<void> _startPlayback() async {
    // Embed-page sources (e.g. VidSrc) are extracted into direct stream URLs
    // before playback; already-direct sources pass through unchanged.
    final resolved = await StreamResolver.resolve(widget.source);
    if (!mounted) return;
    final candidates = <StreamCandidate>[
      ...resolved,
      for (final alt in widget.alternates) StreamCandidate(url: alt, headers: widget.source.headers, isHls: _looksLikeHls(alt)),
    ];
    final winner = await StreamRacer.fastest(candidates) ?? candidates.first;
    if (!mounted) return;
    debugPrint('[MediaKitPlayer] candidates: ${candidates.map((c) => c.url).join(', ')}');
    debugPrint('[MediaKitPlayer] loading HLS: ${winner.url}');
    widget.onUrlChanged?.call(winner.url);
    await _player.open(Media(winner.url.toString(), httpHeaders: winner.headers.isEmpty ? null : winner.headers));
    await _prepareResume();
  }

  Future<void> _prepareResume() async {
    final stored = await ResumeStore.read(_resumeId);
    if (!mounted || stored == null) return;
    setState(() {
      _resumeAt = stored;
      _resumeSecondsLeft = 8;
    });
    _resumeCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resumeSecondsLeft -= 1);
      if (_resumeSecondsLeft <= 0) _applyResume();
    });
  }

  void _applyResume() {
    final target = _resumeAt;
    _dismissResume();
    if (target != null) _player.seek(target);
  }

  void _dismissResume() {
    _resumeCountdown?.cancel();
    _resumeCountdown = null;
    if (mounted) setState(() => _resumeAt = null);
  }

  void _maybeSavePosition(Duration position) {
    if (_duration == Duration.zero) return;
    if ((position - _lastSaved).abs() < const Duration(seconds: 5)) return;
    _lastSaved = position;
    ResumeStore.write(_resumeId, position, _duration);
  }

  static bool _looksLikeHls(Uri url) => url.path.toLowerCase().contains('.m3u8');

  // --- Controls behaviour ---------------------------------------------------

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _playing) setState(() => _controlsVisible = false);
    });
  }

  void _togglePlay() {
    _player.playOrPause();
    _showControls();
  }

  void _seekBy(Duration delta) {
    final target = _position + delta;
    final clamped = target < Duration.zero ? Duration.zero : (target > _duration ? _duration : target);
    _player.seek(clamped);
    _showControls();
  }

  void _toggleMute() {
    _muted = !_muted;
    _player.setVolume(_muted ? 0 : _volume * 100);
    _showControls();
  }

  Future<void> _toggleFullscreen() async {
    await widget.fullscreenController.setFullscreen(!_isFullscreen);
    if (mounted) setState(() => _isFullscreen = !_isFullscreen);
    _showControls();
  }

  bool _isFullscreen = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _resumeCountdown?.cancel();
    if (_duration > Duration.zero && _position > const Duration(seconds: 5)) {
      ResumeStore.write(_resumeId, _position, _duration);
    }
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // A Material ancestor is required by the control widgets (Slider,
    // IconButton); the app shell may be non-Material (e.g. fluent_ui on Windows).
    return Material(
      color: Colors.black,
      child: MouseRegion(
        onHover: (_) => _showControls(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Video(controller: _controller, controls: NoVideoControls, fit: BoxFit.contain),
              if (_buffering && _resumeAt == null) const Center(child: CircularProgressIndicator(color: Colors.white)),
              if (_resumeAt != null) _buildResumeBanner(),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeBanner() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Resume from ${_fmt(_resumeAt!)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text('Continuing in ${_resumeSecondsLeft}s', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 16),
            FilledButton(onPressed: _applyResume, child: const Text('Resume')),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _dismissResume();
                ResumeStore.clear(_resumeId);
              },
              child: const Text('Start over', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: Stack(
          children: [
            if (_resumeAt == null) _buildCenterButtons(),
            Align(alignment: Alignment.bottomCenter, child: _buildBottomBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButtons() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _circleButton(Icons.replay_10, () => _seekBy(const Duration(seconds: -10)), size: 40),
          const SizedBox(width: 32),
          _circleButton(_playing ? Icons.pause : Icons.play_arrow, _togglePlay, size: 64),
          const SizedBox(width: 32),
          _circleButton(Icons.forward_10, () => _seekBy(const Duration(seconds: 10)), size: 40),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {double size = 40}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(size * 0.18),
          child: Icon(icon, color: Colors.white, size: size * 0.6),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSeekBar(),
          Row(
            children: [
              _barButton(_playing ? Icons.pause : Icons.play_arrow, _togglePlay),
              _barButton(_muted ? Icons.volume_off : Icons.volume_up, _toggleMute),
              SizedBox(
                width: 90,
                child: Slider(
                  value: _muted ? 0 : _volume,
                  onChanged: (value) {
                    setState(() {
                      _volume = value;
                      _muted = value == 0;
                    });
                    _player.setVolume(value * 100);
                  },
                ),
              ),
              Text(
                '${_fmt(_scrubTarget != null ? Duration(milliseconds: (_scrubTarget! * _duration.inMilliseconds).round()) : _position)} / ${_fmt(_duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const Spacer(),
              _barButton(Icons.closed_caption, _openSubtitleMenu),
              _barButton(Icons.settings, _openSettingsMenu),
              _barButton(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, _toggleFullscreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar() {
    final total = _duration.inMilliseconds;
    final progress = total == 0 ? 0.0 : (_scrubTarget ?? _position.inMilliseconds / total).clamp(0.0, 1.0);
    final buffered = total == 0 ? 0.0 : (_buffer.inMilliseconds / total).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        void seekToLocal(double dx) {
          final fraction = (dx / constraints.maxWidth).clamp(0.0, 1.0);
          setState(() => _scrubTarget = fraction);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => seekToLocal(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seekToLocal(d.localPosition.dx),
          onHorizontalDragEnd: (_) {
            final target = _scrubTarget;
            _scrubTarget = null;
            if (target != null && total > 0) _player.seek(Duration(milliseconds: (target * total).round()));
          },
          onTapDown: (d) {
            final fraction = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            if (total > 0) _player.seek(Duration(milliseconds: (fraction * total).round()));
          },
          child: SizedBox(
            height: 16,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 4, color: Colors.white24),
                FractionallySizedBox(
                  widthFactor: buffered,
                  child: Container(height: 4, color: Colors.white38),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(height: 4, color: const Color(0xFFE50914)),
                ),
                Align(
                  alignment: Alignment(progress * 2 - 1, 0),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _barButton(IconData icon, VoidCallback onTap) => IconButton(
    onPressed: onTap,
    icon: Icon(icon, color: Colors.white),
    iconSize: 22,
    splashRadius: 22,
  );

  // --- Track menus ----------------------------------------------------------

  void _openSettingsMenu() {
    _showControls();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15151C),
      builder: (context) {
        final videoTracks = _tracks.video.where((t) => t.id != 'no').toList();
        final audioTracks = _tracks.audio.where((t) => t.id != 'no').toList();
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (videoTracks.length > 1) ...[
                  _menuHeader('Quality'),
                  for (final track in videoTracks)
                    _menuTile(_qualityLabel(track), _selected.video.id == track.id, () {
                      _player.setVideoTrack(track);
                      Navigator.pop(context);
                    }),
                ],
                if (audioTracks.length > 1) ...[
                  _menuHeader('Audio'),
                  for (final track in audioTracks)
                    _menuTile(_trackLabel(track.title, track.language, track.id), _selected.audio.id == track.id, () {
                      _player.setAudioTrack(track);
                      Navigator.pop(context);
                    }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSubtitleMenu() {
    _showControls();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15151C),
      builder: (context) {
        final subtitleTracks = _tracks.subtitle.where((t) => t.id != 'auto').toList();
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _menuHeader('Subtitles'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _uploadSubtitle();
                      },
                      icon: const Icon(Icons.upload_file, color: Colors.white70, size: 18),
                      label: const Text('Upload', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
                for (final track in subtitleTracks)
                  _menuTile(track.id == 'no' ? 'Off' : _trackLabel(track.title, track.language, track.id), _selected.subtitle.id == track.id, () {
                    _player.setSubtitleTrack(track);
                    Navigator.pop(context);
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadSubtitle() async {
    const typeGroup = XTypeGroup(label: 'subtitles', extensions: ['srt', 'vtt', 'txt']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final raw = await file.readAsString();
    final vtt = _toVtt(raw);
    await _player.setSubtitleTrack(SubtitleTrack.data(vtt, title: file.name));
  }

  /// Converts SRT to WebVTT, leaving existing VTT untouched, mirroring the
  /// reference player's `srtToVtt`.
  static String _toVtt(String input) {
    var text = input.replaceAll('\uFEFF', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (text.trimLeft().startsWith('WEBVTT')) return text;
    text = text.replaceAllMapped(RegExp(r'(\d{2}:\d{2}:\d{2}),(\d{3})'), (m) => '${m[1]}.${m[2]}');
    return 'WEBVTT\n\n${text.trimLeft()}';
  }

  Widget _menuHeader(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold),
      ),
    ),
  );

  Widget _menuTile(String label, bool selected, VoidCallback onTap) => ListTile(
    dense: true,
    leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? const Color(0xFFE50914) : Colors.white38, size: 20),
    title: Text(label, style: const TextStyle(color: Colors.white)),
    onTap: onTap,
  );

  String _qualityLabel(VideoTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.h != null) return '${track.h}p';
    return _trackLabel(track.title, track.language, track.id);
  }

  String _trackLabel(String? title, String? language, String id) {
    if (id == 'auto') return 'Auto';
    if (title != null && title.isNotEmpty) return title;
    if (language != null && language.isNotEmpty) return language;
    return 'Track $id';
  }

  String _fmt(Duration d) {
    final seconds = d.inSeconds;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
    return h > 0 ? '$h:$mm:${s.toString().padLeft(2, '0')}' : '$mm:${s.toString().padLeft(2, '0')}';
  }
}
