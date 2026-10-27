import 'dart:convert';

import 'package:popcorn_server_core/popcorn_server_core.dart';

final class PlayerPageRenderer {
  const PlayerPageRenderer._();

  static String render({required List<ProviderSummary> providers, MediaRequest? initialMedia, Uri? embedUrl, String? session, bool showForm = true}) {
    final providerOptions = providers.map((provider) => '<option value="${_escape(provider.id)}">${_escape(provider.label)}</option>').join();
    final initialMediaJson = jsonEncode(
      initialMedia == null
          ? null
          : {
              'providerId': initialMedia.providerId,
              'type': initialMedia.type,
              'id': initialMedia.id,
              'lang': initialMedia.lang,
              'sub': initialMedia.sub,
              'season': initialMedia.season,
              'episode': initialMedia.episode,
            },
    ).replaceAll('<', r'\u003c');
    final embedUrlJson = jsonEncode(embedUrl?.toString()).replaceAll('<', r'\u003c');
    final sessionJson = jsonEncode(session).replaceAll('<', r'\u003c');

    return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Popcorn Player</title>
  <style>
    :root{color-scheme:dark;font-family:system-ui,sans-serif;background:#08090b;color:#f5f5f5}
    *{box-sizing:border-box}html,body{margin:0;min-height:100%;background:#08090b}
    main{min-height:100vh;display:flex;flex-direction:column}
    header{display:flex;align-items:end;gap:10px;flex-wrap:wrap;padding:14px 18px;border-bottom:1px solid #303238}
    h1{font-size:16px;margin:0 10px 5px 0}.field{display:grid;gap:4px;color:#b8bdc6;font-size:12px}
    input,select,button{font:inherit;color:inherit;background:#17191e;border:1px solid #444851;border-radius:4px;padding:8px}
    input:focus,select:focus,button:focus-visible{outline:2px solid #e50914;outline-offset:2px}
    #media-id{width:190px}button{cursor:pointer}button[type=submit]{background:#e50914;border-color:#e50914}
    #now-playing{padding:10px 18px;color:#b8bdc6;font-size:13px}
    #stage{position:relative;display:flex;flex:1;min-height:60vh;background:#000}
    video,iframe{width:100%;height:100%;min-height:60vh;border:0;background:#000;object-fit:contain}
    #start-playback{position:absolute;z-index:2;top:50%;left:50%;transform:translate(-50%,-50%);width:64px;height:64px;border-radius:50%;font-size:16px;background:#d71920;border-color:#fff;box-shadow:0 4px 20px #0009}
    #video-loading{position:absolute;z-index:2;inset:0;display:grid;place-items:center;pointer-events:none}
    #video-loading::after{content:'';width:42px;height:42px;border:4px solid #ffffff45;border-top-color:#fff;border-radius:50%;animation:spin .8s linear infinite}
    @keyframes spin{to{transform:rotate(360deg)}}
    #fullscreen-toggle{position:absolute;z-index:2;right:16px;top:16px;background:#25282ecc;border-color:#ffffff55}
    #fullscreen-toggle[data-inactive="true"]{opacity:0;transition:opacity .25s}
    #settings-toggle{position:absolute;z-index:2;right:16px;top:60px;background:#25282ecc;border-color:#ffffff55}
    #retry{position:absolute;z-index:4;left:50%;bottom:16px;transform:translateX(-50%)}
    #skip-actions{position:absolute;right:16px;bottom:18px;z-index:2;display:flex;gap:8px}
    #skip-actions button{background:#25282ecc;border:1px solid #ffffff55;border-radius:4px;padding:9px 12px;font-weight:600}
    #skip-actions button:hover{background:#41444c}
    #playback-settings{position:absolute;z-index:3;right:16px;bottom:16px;width:min(340px,calc(100vw - 32px));max-height:calc(100% - 32px);overflow:auto;padding:14px;background:#17191ef2;border:1px solid #555a64;border-radius:4px;box-shadow:0 8px 28px #0009}
    #playback-settings h2{font-size:15px;margin:0 auto 8px 0}
    #playback-settings .settings-heading{display:flex;align-items:center;margin-bottom:8px}
    #playback-settings label{display:grid;gap:4px;margin:8px 0;color:#c5c9d0;font-size:12px}
    #playback-settings select{width:100%}
    #playback-settings .subtitle-delay{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:12px}
    #playback-settings .subtitle-delay-controls{display:flex;align-items:center;gap:6px}
    #playback-settings output{min-width:42px;text-align:center;font-variant-numeric:tabular-nums}
    #settings-close{padding:3px 8px;font-size:18px}
    #provider-note,#subtitle-delay-note{font-size:12px;color:#b8bdc6}
    #status{padding:10px 18px;color:#b8bdc6;font-size:13px}
    footer{display:flex;gap:10px;align-items:center;flex-wrap:wrap;padding:10px 18px}
    footer label{display:flex;gap:6px;align-items:center;font-size:12px;color:#b8bdc6}
    .subtitle-delay button{padding:5px 8px}
    [hidden]{display:none!important}
    @media(max-width:640px){header{align-items:flex-start;flex-direction:column}#media-id{width:min(220px,85vw)}#stage,video,iframe{min-height:48vh}}
  </style>
</head>
<body>
  <main>
    ${showForm ? '''<header>
      <h1>Popcorn Player</h1>
      <form id="media-form">
        <label class="field">Provider<select id="media-provider">$providerOptions</select></label>
        <label class="field">Type<select id="media-type"><option value="movie">Movie</option><option value="tv">TV show</option></select></label>
        <label class="field">ID<input id="media-id" required pattern="(?:tt[0-9]+|[0-9]+)" placeholder="IMDb or TMDB ID"></label>
        <label class="field">Language<select id="media-language"><option value="en">English</option><option value="es">Spanish</option><option value="fr">French</option><option value="de">German</option><option value="it">Italian</option><option value="pt">Portuguese</option><option value="ja">Japanese</option><option value="ko">Korean</option></select></label>
        <label class="field">Subtitles<select id="media-subtitles"><option value="1">On</option><option value="0">Off</option></select></label>
        <label class="field episode">Season<input id="media-season" type="number" min="1" value="1"></label>
        <label class="field episode">Episode<input id="media-episode" type="number" min="1" value="1"></label>
        <button type="submit">Play</button>
      </form>
    </header>''' : ''}
    <div id="now-playing" hidden></div>
    <section id="stage"><video id="video" playsinline controlslist="nofullscreen" hidden></video><iframe id="embed" title="Provider player" allow="autoplay; fullscreen; encrypted-media; picture-in-picture" allowfullscreen referrerpolicy="strict-origin-when-cross-origin" hidden></iframe><button id="start-playback" type="button" aria-label="Start playback" hidden>Play</button><div id="video-loading" role="status" aria-label="Loading video" hidden></div><button id="fullscreen-toggle" type="button" aria-label="Enter fullscreen" aria-pressed="false" hidden>Fullscreen</button><div id="skip-actions" hidden><button id="skip-intro" type="button" hidden>Skip intro</button><button id="next-episode" type="button" hidden>Next episode</button></div><section id="playback-settings" role="dialog" aria-label="Playback settings" hidden><div class="settings-heading"><h2>Playback settings</h2><button id="settings-close" type="button" aria-label="Close settings">&times;</button></div><label for="settings-provider">Provider<select id="settings-provider" disabled>$providerOptions</select></label><label for="playback-language">Language<select id="playback-language"><option value="en">English</option><option value="es">Spanish</option><option value="fr">French</option><option value="de">German</option><option value="it">Italian</option><option value="pt">Portuguese</option><option value="ja">Japanese</option><option value="ko">Korean</option></select></label><label id="source-field" hidden>Source<select id="source-select" disabled></select></label><label id="quality-field" hidden>Quality<select id="quality-select" disabled><option value="-1">Auto</option></select></label><label for="subtitle-select">Subtitles<select id="subtitle-select" disabled><option value="">Off</option></select></label><div id="subtitle-delay" class="subtitle-delay" hidden><span>Subtitle timing</span><div class="subtitle-delay-controls"><button id="subtitle-delay-decrease" type="button" aria-label="Decrease subtitle timing by half a second">-0.5 s</button><output id="subtitle-delay-value" aria-live="polite">0 s</output><button id="subtitle-delay-increase" type="button" aria-label="Increase subtitle timing by half a second">+0.5 s</button></div></div><p id="subtitle-delay-note" hidden></p><p id="provider-note" hidden>Source and quality are managed in the provider player. Language and subtitles depend on provider support.</p></section></section>
    <div id="status" role="status">Enter an ID supported by the selected provider.</div>
    <footer><span id="skip-status" role="status"></span><button id="retry" type="button" hidden>Retry</button><button id="settings-toggle" type="button" aria-label="Playback settings" aria-controls="playback-settings" aria-expanded="false" hidden>Settings</button></footer>
  </main>
  <script src="https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js"></script>
  <script>
    const providers = ${jsonEncode([
      for (final provider in providers) {'id': provider.id, 'label': provider.label},
    ])};
    const initialMedia = $initialMediaJson;
    const embedUrl = $embedUrlJson;
    const playbackSession = $sessionJson;
    const query = new URLSearchParams(location.search);
    const video = document.getElementById('video');
    const stage = document.getElementById('stage');
    const frame = document.getElementById('embed');
    const status = document.getElementById('status');
    const skipStatus = document.getElementById('skip-status');
    const startPlaybackButton = document.getElementById('start-playback');
    const videoLoading = document.getElementById('video-loading');
    const fullscreenToggle = document.getElementById('fullscreen-toggle');
    const settingsToggle = document.getElementById('settings-toggle');
    stage.append(settingsToggle);
    const settingsPanel = document.getElementById('playback-settings');
    const settingsClose = document.getElementById('settings-close');
    const settingsProvider = document.getElementById('settings-provider');
    const playbackLanguage = document.getElementById('playback-language');
    const providerNote = document.getElementById('provider-note');
    const subtitleDelayNote = document.getElementById('subtitle-delay-note');
    const sourceSelect = document.getElementById('source-select');
    const qualitySelect = document.getElementById('quality-select');
    const qualityField = document.getElementById('quality-field');
    const subtitleSelect = document.getElementById('subtitle-select');
    const subtitleDelay = document.getElementById('subtitle-delay');
    const subtitleDelayValue = document.getElementById('subtitle-delay-value');
    const retryButton = document.getElementById('retry');
    stage.append(retryButton);
    const skipActions = document.getElementById('skip-actions');
    const skipIntro = document.getElementById('skip-intro');
    const nextEpisode = document.getElementById('next-episode');
    const nextSeason = query.get('nextSeason');
    const nextEpisodeNumber = query.get('nextEpisode');
    let hls;
    let mediaRecoveryAttempted = false;
    let playbackStarting = false;
    let hasUserStartedPlayback = false;
    let fullscreenHideTimer;
    let fullscreenPointerFocus = false;
    let skipTimestamps = {intro:[],credits:[]};
    let selectedMedia;
    let activeSource = '';
    let activeSubtitle = '';
    let lastProgress = 0;
    let introEnd = null;
    let skipRequest = 0;
    let timestampMedia = null;
    let timestampDuration = 0;
    const requestedSubtitleDelay = Number(query.get('resumeSubtitleDelay') || 0);
    let subtitleDelaySeconds = Number.isFinite(requestedSubtitleDelay) ? requestedSubtitleDelay : 0;
    let resumeSubtitlePreference = query.get('resumeSubtitles') || '';
    let activeSubtitleTrack;
    const subtitleCueTimes = new WeakMap();

    function mediaQuery(media) {
      const values = new URLSearchParams({provider:media.providerId,type:media.type,id:media.id,lang:media.lang,sub:media.sub});
      if (media.type === 'tv') { values.set('season',media.season); values.set('episode',media.episode); }
      if (playbackSession) values.set('session',playbackSession);
      return values;
    }
    function showSettings(open) {
      settingsPanel.hidden = !open;
      settingsToggle.ariaExpanded = String(open);
      if (open) settingsClose.focus();
      else settingsToggle.focus();
    }
    settingsToggle.addEventListener('click', () => showSettings(settingsPanel.hidden));
    settingsClose.addEventListener('click', () => showSettings(false));
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && !settingsPanel.hidden) showSettings(false);
    });
    function setVideoLoading(loading) {
      videoLoading.hidden = !loading;
      video.controls = !loading && !video.hidden && retryButton.hidden && hasUserStartedPlayback;
      startPlaybackButton.hidden = loading || video.hidden || !retryButton.hidden || hasUserStartedPlayback || playbackStarting || Boolean(embedUrl);
    }
    function fail(message) {
      retryButton.hidden = false;
      setVideoLoading(false);
      status.textContent = message;
    }
    function updateFullscreenControl() {
      const fullscreen = document.fullscreenElement === stage;
      fullscreenToggle.hidden = Boolean(embedUrl) || !hasUserStartedPlayback || typeof stage.requestFullscreen !== 'function';
      fullscreenToggle.textContent = fullscreen ? 'Exit fullscreen' : 'Fullscreen';
      fullscreenToggle.ariaLabel = fullscreen ? 'Exit fullscreen' : 'Enter fullscreen';
      fullscreenToggle.ariaPressed = String(fullscreen);
      showFullscreenControl();
      updateSkipActions();
    }
    function showFullscreenControl(event) {
      if (event?.type === 'focusout' && fullscreenToggle.dataset.inactive === 'true') return;
      if (event?.type === 'pointerdown') fullscreenPointerFocus = true;
      if (event?.type === 'keydown') fullscreenPointerFocus = false;
      clearTimeout(fullscreenHideTimer);
      fullscreenToggle.dataset.inactive = 'false';
      if (fullscreenToggle.hidden || document.fullscreenElement !== stage || video.paused || video.ended) return;
      fullscreenHideTimer = setTimeout(() => {
        if (document.fullscreenElement === stage && !video.paused && !video.ended && (document.activeElement !== fullscreenToggle || fullscreenPointerFocus)) {
          fullscreenToggle.dataset.inactive = 'true';
        }
      }, 3000);
    }
    for (const event of ['pointermove','pointerdown','keydown','focusin','focusout']) stage.addEventListener(event, showFullscreenControl);
    for (const event of ['playing','pause','ended']) video.addEventListener(event, showFullscreenControl);
    window.addEventListener('pagehide', () => clearTimeout(fullscreenHideTimer));
    document.addEventListener('fullscreenchange', updateFullscreenControl);
    fullscreenToggle.addEventListener('click', async () => {
      try {
        if (document.fullscreenElement === stage) await document.exitFullscreen();
        else await stage.requestFullscreen();
        updateFullscreenControl();
      } catch (error) {
        status.textContent = 'Could not change fullscreen: ' + error.message;
      }
    });
    startPlaybackButton.addEventListener('click', async () => {
      playbackStarting = true;
      startPlaybackButton.disabled = true;
      video.muted = false;
      setVideoLoading(true);
      let fullscreenRequest;
      let playbackRequest;
      try {
        fullscreenRequest = typeof stage.requestFullscreen === 'function'
          ? stage.requestFullscreen()
          : Promise.reject(new Error('Fullscreen is unavailable'));
      } catch (error) {
        fullscreenRequest = Promise.reject(error);
      }
      try {
        playbackRequest = video.play();
      } catch (error) {
        playbackRequest = Promise.reject(error);
      }
      const [fullscreenResult, playbackResult] = await Promise.allSettled([Promise.resolve(fullscreenRequest), playbackRequest]);
      playbackStarting = false;
      if (playbackResult.status === 'rejected') {
        startPlaybackButton.disabled = false;
        setVideoLoading(false);
        status.textContent = 'Could not start playback: ' + (playbackResult.reason?.message || playbackResult.reason);
        return;
      }
      hasUserStartedPlayback = true;
      setVideoLoading(video.readyState < 3 || video.seeking);
      updateFullscreenControl();
      startPlaybackButton.hidden = true;
      status.textContent = fullscreenResult.status === 'rejected' ? 'Playing; fullscreen is unavailable in this view.' : '';
    });
    qualitySelect.disabled = true;
    sourceSelect.disabled = true;
    subtitleSelect.disabled = true;
    settingsProvider.value = initialMedia?.providerId || providers[0]?.id || '';
    playbackLanguage.value = initialMedia?.lang || query.get('lang') || 'en';
    playbackLanguage.addEventListener('change', () => {
      if (selectedMedia) play({...selectedMedia,lang:playbackLanguage.value},activeSource);
    });
    function applySubtitleDelay() {
      const cues = activeSubtitleTrack?.track?.cues;
      if (!cues) return;
      for (const cue of cues) {
        if (!subtitleCueTimes.has(cue)) {
          subtitleCueTimes.set(cue, {start:cue.startTime,end:cue.endTime});
        }
        const original = subtitleCueTimes.get(cue);
        cue.startTime = Math.max(0, original.start + subtitleDelaySeconds);
        cue.endTime = Math.max(cue.startTime, original.end + subtitleDelaySeconds);
      }
    }
    function updateSubtitleDelay() {
      const delay = Math.round(subtitleDelaySeconds * 10) / 10;
      subtitleDelayValue.textContent = (delay > 0 ? '+' : '') + delay + ' s';
      applySubtitleDelay();
    }
    function updateQualityOptions() {
      if (!hls || !hls.levels.length) {
        qualityField.hidden = true;
        qualitySelect.disabled = true;
        return;
      }
      const selected = qualitySelect.value;
      qualitySelect.replaceChildren(new Option('Auto', '-1'));
      const levels = hls.levels.map((level, index) => ({level,index})).sort((a,b) => (b.level.height || 0) - (a.level.height || 0));
      for (const {level,index} of levels) {
        const resolution = level.height ? level.height + 'p' : 'Level ' + (index + 1);
        const bitrate = level.bitrate ? ' · ' + (level.bitrate / 1000000).toFixed(1) + ' Mbps' : '';
        qualitySelect.add(new Option(resolution + bitrate, String(index)));
      }
      qualityField.hidden = false;
      qualitySelect.disabled = false;
      qualitySelect.value = selected;
      if (qualitySelect.value === '') qualitySelect.value = '-1';
    }
    qualitySelect.addEventListener('change', () => {
      if (hls) hls.currentLevel = Number(qualitySelect.value);
    });
    document.getElementById('subtitle-delay-decrease').addEventListener('click', () => {
      subtitleDelaySeconds -= 0.5;
      updateSubtitleDelay();
      report('subtitle-delay');
    });
    document.getElementById('subtitle-delay-increase').addEventListener('click', () => {
      subtitleDelaySeconds += 0.5;
      updateSubtitleDelay();
      report('subtitle-delay');
    });
    retryButton.addEventListener('click', () => selectedMedia && play(selectedMedia, activeSource));
    for (const event of ['loadstart','waiting','seeking']) {
      video.addEventListener(event, () => {
        if (hasUserStartedPlayback) setVideoLoading(true);
      });
    }
    for (const event of ['loadeddata','canplay','canplaythrough']) {
      video.addEventListener(event, () => {
        if (hasUserStartedPlayback) setVideoLoading(video.readyState < 3 || video.seeking);
        else setVideoLoading(false);
      });
    }
    video.addEventListener('playing', () => {
      if (hasUserStartedPlayback) setVideoLoading(false);
    });
    function updateSkipActions() {
      const position = video.currentTime;
      const ready = !embedUrl && selectedMedia && hasUserStartedPlayback && !resumePosition && !video.hidden && !video.ended && Number.isFinite(position);
      const contains = (segment) => position >= segment.start && (segment.end == null || position < segment.end);
      const intro = ready && skipTimestamps.intro.find((segment) => segment.end != null && segment.end <= video.duration && contains(segment));
      introEnd = intro ? intro.end : null;
      skipIntro.hidden = introEnd == null;
      const hasNext = ready && selectedMedia.type === 'tv' && Number.isSafeInteger(Number(nextSeason)) && String(Number(nextSeason)) === nextSeason && Number(nextSeason) > 0 && Number.isSafeInteger(Number(nextEpisodeNumber)) && String(Number(nextEpisodeNumber)) === nextEpisodeNumber && Number(nextEpisodeNumber) > 0;
      const inCredits = skipTimestamps.credits.some(contains);
      const nearEnd = skipTimestamps.credits.length === 0 && Number.isFinite(video.duration) && video.duration > 0 && position >= 0 && position <= video.duration && video.duration - position <= 20;
      nextEpisode.textContent = hasNext && Number(nextSeason) > Number(selectedMedia.season) ? 'Next season' : 'Next episode';
      nextEpisode.hidden = !(hasNext && (inCredits || nearEnd));
      skipActions.hidden = skipIntro.hidden && nextEpisode.hidden;
    }
    async function loadSkipTimestamps() {
      if (embedUrl || !selectedMedia || !Number.isFinite(video.duration) || video.duration <= 0) return;
      const media = selectedMedia;
      const duration = Math.round(video.duration * 1000);
      if (timestampMedia === media && Math.abs(timestampDuration - duration) < 1000) return;
      const request = ++skipRequest;
      timestampMedia = media;
      timestampDuration = duration;
      skipStatus.textContent = '';
      const params = mediaQuery(media);
      params.set('duration_ms', String(duration));
      try {
        const data = await json('/introdb?' + params);
        if (request !== skipRequest || selectedMedia !== media) return;
        const parse = (segments) => {
          if (segments == null) return [];
          if (!Array.isArray(segments)) throw new Error('Invalid IntroDB segments');
          return segments.map((segment) => {
            const start = segment?.start_ms;
            const end = segment?.end_ms;
            if ((start != null && (!Number.isFinite(start) || start < 0)) ||
                (end != null && (!Number.isFinite(end) || end < 0)) ||
                (start == null && end == null) || (end != null && end <= (start ?? 0))) {
              throw new Error('Invalid IntroDB timestamps');
            }
            return {start:(start ?? 0) / 1000,end:end == null ? null : end / 1000};
          });
        };
        skipTimestamps = {intro:parse(data.intro),credits:parse(data.credits)};
        updateSkipActions();
      } catch (error) {
        if (request !== skipRequest) return;
        skipTimestamps = {intro:[],credits:[]};
        skipStatus.textContent = 'Skip controls unavailable: ' + error.message;
      }
    }
    for (const event of ['loadedmetadata','durationchange']) video.addEventListener(event, loadSkipTimestamps);
    for (const event of ['timeupdate','seeked','playing','pause','ended']) video.addEventListener(event, updateSkipActions);
    skipIntro.addEventListener('click', () => {
      updateSkipActions();
      if (introEnd == null) return;
      video.currentTime = introEnd;
      updateSkipActions();
    });
    nextEpisode.addEventListener('click', () => {
      updateSkipActions();
      if (nextEpisode.hidden) return;
      const message = {type:'popcorn:next',media:{type:selectedMedia.type,id:selectedMedia.id,season:selectedMedia.season,episode:selectedMedia.episode},session:{provider:selectedMedia.providerId,source:activeSource,language:selectedMedia.lang,subtitles:activeSubtitle,subtitleDelaySeconds,positionSeconds:video.currentTime}};
      const parentOrigin = query.get('parentOrigin');
      if (window.parent !== window && parentOrigin) {
        window.parent.postMessage(message,parentOrigin);
      } else if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('popcornPlayback',message);
      } else {
        const nextMedia = {...selectedMedia,season:nextSeason,episode:nextEpisodeNumber};
        const params = mediaQuery(nextMedia);
        params.set('resume',String(video.currentTime));
        if (activeSubtitle) params.set('resumeSubtitles',activeSubtitle);
        params.set('resumeSource',activeSource);
        params.set('resumeSubtitleDelay',String(subtitleDelaySeconds));
        if (parentOrigin) params.set('parentOrigin',parentOrigin);
        for (const key of ['title','year','nextSeason','nextEpisode']) {
          const value = query.get(key);
          if (value) params.set(key,value);
        }
        window.location.replace('/player?' + params);
      }
    });
    const requestedPosition = Number(query.get('resume') || 0);
    let resumePosition = Number.isFinite(requestedPosition) ? Math.max(0, requestedPosition) : 0;
    function restorePosition() {
      if (!resumePosition || !Number.isFinite(video.duration) || video.duration <= 0) return;
      video.currentTime = Math.min(resumePosition, Math.max(0, video.duration - 0.1));
      resumePosition = 0;
    }
    video.addEventListener('loadedmetadata', restorePosition);
    video.addEventListener('durationchange', restorePosition);
    function report(event, overrides = {}) {
      if (!selectedMedia) return;
      const message = {type:'popcorn:playback',event,media:{type:selectedMedia.type,id:selectedMedia.id,season:selectedMedia.season,episode:selectedMedia.episode},session:{provider:selectedMedia.providerId,source:activeSource,language:selectedMedia.lang,subtitles:activeSubtitle,subtitleDelaySeconds,positionSeconds:video.ended?0:(Number.isFinite(video.currentTime)?video.currentTime:0),...overrides}};
      const parentOrigin = query.get('parentOrigin');
      if (window.parent !== window && parentOrigin) window.parent.postMessage(message,parentOrigin);
      window.flutter_inappwebview?.callHandler('popcornPlayback',message);
    }
    async function json(path) {
      const response = await fetch(path);
      if (!response.ok) throw new Error('Request failed ('+response.status+')');
      return response.json();
    }
    function disposeVideo() { if (hls) { hls.destroy(); hls = null; } video.pause(); video.removeAttribute('src'); video.load(); }
    async function play(media, sourceId = query.get('resumeSource') || '') {
      selectedMedia = {...media};
      playbackLanguage.value = selectedMedia.lang;
      settingsProvider.value = selectedMedia.providerId;
      skipRequest++;
      skipTimestamps = {intro:[],credits:[]};
      timestampMedia = null;
      timestampDuration = 0;
      mediaRecoveryAttempted = false;
      playbackStarting = false;
      hasUserStartedPlayback = false;
      retryButton.hidden = true;
      retryButton.disabled = false;
      qualityField.hidden = true;
      subtitleDelay.hidden = true;
      activeSource = sourceId;
      sourceSelect.disabled = true;
      qualitySelect.disabled = true;
      subtitleSelect.disabled = true;
      video.controls = false;
      startPlaybackButton.disabled = false;
      startPlaybackButton.hidden = true;
      frame.hidden = true;
      video.hidden = true;
      sourceSelect.replaceChildren();
      subtitleSelect.replaceChildren(new Option('Off',''));
      document.getElementById('source-field').hidden = true;
      disposeVideo();
      if (embedUrl) {
        frame.src = embedUrl;
        frame.hidden = false;
        settingsToggle.hidden = false;
        providerNote.hidden = false;
        subtitleDelayNote.textContent = 'Subtitle timing is controlled by the provider player.';
        subtitleDelayNote.hidden = false;
        subtitleSelect.disabled = true;
        status.textContent = 'Playing provider video';
        return;
      }
      const params = mediaQuery(media);
      try {
        const sources = await json('/sources?'+params);
        if (sources.length) {
          document.getElementById('source-field').hidden = false;
          sourceSelect.disabled = false;
          sourceSelect.add(new Option('Auto',''));
          for (const source of sources) sourceSelect.add(new Option(source.label,source.id));
          sourceSelect.value = sourceId;
        }
      } catch (_) {}
      try {
        const tracks = await json('/subtitles?'+params);
        for (const track of tracks) subtitleSelect.add(new Option(track.label,track.id));
        subtitleSelect.disabled = tracks.length === 0;
      } catch (_) {}
      const preferredSubtitle = activeSubtitle || resumeSubtitlePreference;
      resumeSubtitlePreference = '';
      if (preferredSubtitle && Array.from(subtitleSelect.options).some((option) => option.value === preferredSubtitle)) {
        subtitleSelect.value = preferredSubtitle;
        subtitleSelect.dispatchEvent(new Event('change'));
      }
      if (sourceId) params.set('source',sourceId);
      const manifest = '/manifest?'+params;
      video.hidden = false;
      settingsToggle.hidden = false;
      providerNote.hidden = true;
      subtitleDelayNote.hidden = true;
      subtitleSelect.disabled = subtitleSelect.options.length <= 1;
      setVideoLoading(true);
      if (window.Hls && Hls.isSupported()) {
        hls = new Hls();
        hls.on(Hls.Events.MANIFEST_PARSED, () => {
          status.textContent = 'Ready to play';
          updateQualityOptions();
          setVideoLoading(video.readyState < 3 || video.seeking);
        });
        hls.on(Hls.Events.LEVELS_UPDATED, updateQualityOptions);
        hls.on(Hls.Events.ERROR, (_, data) => {
          if (!data.fatal) return;
          if (data.type === Hls.ErrorTypes.MEDIA_ERROR && !mediaRecoveryAttempted) {
            mediaRecoveryAttempted = true;
            status.textContent = 'Recovering playback';
            hls.recoverMediaError();
            return;
          }
          status.textContent = 'Playback failed: ' + data.details;
          fail('Playback failed: ' + data.details);
        });
        hls.loadSource(manifest); hls.attachMedia(video);
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = manifest;
      } else {
        fail('This browser does not support HLS playback.');
        return;
      }
      status.textContent = 'Loading stream';
    }
    sourceSelect.addEventListener('change', () => selectedMedia && play(selectedMedia,sourceSelect.value));
    subtitleSelect.addEventListener('change', () => {
      activeSubtitle = subtitleSelect.value;
      activeSubtitleTrack = null;
      subtitleDelay.hidden = !activeSubtitle || Boolean(embedUrl);
      for (const track of video.querySelectorAll('track')) track.remove();
      if (activeSubtitle && selectedMedia) {
        const selected = subtitleSelect.selectedOptions[0];
        const track = document.createElement('track'); track.kind='subtitles'; track.label=selected.text; track.srclang='en';
        track.src='/subtitle/'+encodeURIComponent(activeSubtitle)+(playbackSession?'?session='+encodeURIComponent(playbackSession):'');
        track.default=true;
        track.addEventListener('load', applySubtitleDelay);
        video.append(track);
        activeSubtitleTrack = track;
        updateSubtitleDelay();
      }
      report('subtitle');
    });
    video.addEventListener('error', () => {
      if (video.hidden || embedUrl) return;
      status.textContent = 'Playback failed. Retry the stream.';
      retryButton.hidden = false;
    });
    video.addEventListener('playing',() => { status.textContent='Playing'; report('ready'); });
    video.addEventListener('pause',() => report('pause'));
    video.addEventListener('seeked',() => report('seeked'));
    video.addEventListener('timeupdate',() => { if (Date.now()-lastProgress>5000) { lastProgress=Date.now(); report('progress'); } });
    video.addEventListener('ended',() => report('ended',{positionSeconds:0}));
    window.addEventListener('pagehide',() => report('pagehide'));
    const form = document.getElementById('media-form');
    if (form) {
      const type = document.getElementById('media-type');
      const episodes = document.querySelectorAll('.episode');
      const updateEpisodeFields = () => episodes.forEach(field => field.hidden = type.value !== 'tv');
      type.addEventListener('change',updateEpisodeFields); updateEpisodeFields();
      form.addEventListener('submit',event => {
        event.preventDefault();
        const media = {providerId:document.getElementById('media-provider').value,type:type.value,id:document.getElementById('media-id').value,lang:document.getElementById('media-language').value,sub:document.getElementById('media-subtitles').value,season:document.getElementById('media-season').value,episode:document.getElementById('media-episode').value};
        const url = new URL('/player',location.href); for (const [key,value] of Object.entries(media)) if (key !== 'season' && key !== 'episode' || media.type === 'tv') url.searchParams.set(key === 'providerId' ? 'provider' : key,value);
        location.href=url;
      });
    }
    updateSubtitleDelay();
    if (initialMedia) {
      const now = document.getElementById('now-playing');
      const title = (query.get('title') || '').trim();
      const year = (query.get('year') || '').trim();
      const validYear = year.length === 4 && [...year].every((digit) => digit >= '0' && digit <= '9');
      const name = title ? title + (validYear ? ' ' + year : '') : (initialMedia.type === 'movie' ? 'Movie ' : 'TV ') + initialMedia.id;
      const pad = (value) => String(value).padStart(2, '0');
      now.textContent = name + (initialMedia.type === 'tv' ? ' S' + pad(initialMedia.season) + ' E' + pad(initialMedia.episode) : '');
      now.hidden = false;
      play(initialMedia);
    }
  </script>
</body>
</html>''';
  }

  static String _escape(String value) =>
      value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
}
