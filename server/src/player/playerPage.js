function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
}

function renderPlayerPage(initialMedia, { providers = [], showForm = true } = {}) {
  const selectedType = initialMedia?.type || 'movie';
  const selectedProvider = initialMedia?.providerId || providers[0]?.id || '';
  const selectedLanguage = initialMedia?.lang || 'en';
  const selectedSubtitles = initialMedia?.sub ?? '1';
  const playbackMedia = initialMedia
    ? { ...initialMedia, providerId: selectedProvider, lang: selectedLanguage, sub: selectedSubtitles }
    : null;
  const initialId = initialMedia?.id || '';
  const initialSeason = initialMedia?.season || '1';
  const initialEpisode = initialMedia?.episode || '1';
  const providerOptions = providers.map(({ id, label }) =>
    `<option value="${escapeHtml(id)}"${id === selectedProvider ? ' selected' : ''}>${escapeHtml(label)}</option>`,
  ).join('');

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>VidSrc Player</title>
  <style>
    html,body{margin:0;height:100%;background:#08090b;color:#f5f5f5;font-family:system-ui,sans-serif}
    main{min-height:100%;display:flex;flex-direction:column}
    header{padding:16px 20px;border-bottom:1px solid #292b30;display:flex;align-items:center;gap:20px;flex-wrap:wrap}
    h1{font-size:16px;margin:0 12px 0 0;white-space:nowrap}
    form{display:flex;align-items:end;gap:10px;flex-wrap:wrap}
    .field{display:grid;gap:5px;color:#aeb3bd;font-size:11px}
    input,form select{min-height:34px;box-sizing:border-box;padding:6px 9px;background:#17191e;color:#f5f5f5;border:1px solid #41444c;border-radius:4px;font:inherit;font-size:13px}
    input:focus,form select:focus,button:focus-visible{outline:2px solid #e50914;outline-offset:2px}
    #media-id{width:190px}
    .episode-field[hidden]{display:none}
    form button{min-height:34px;padding:0 14px;background:#e50914;border:0;border-radius:4px;color:white;font-weight:700}
    form button:hover{background:#ff2631}
    #now-playing{padding:10px 20px 0;color:#aeb3bd;font-size:13px}
    #video-container{position:relative;display:flex;flex:1;min-height:0;background:#000}
    #video-container[hidden],#video-loading[hidden]{display:none}
    video{width:100%;flex:1;min-height:0;background:#000}
    #video-loading{position:absolute;inset:0;display:grid;place-items:center;pointer-events:none}
    #video-loading::after{content:'';width:44px;height:44px;border:4px solid #ffffff40;border-top-color:#fff;border-radius:50%;animation:video-loading-spin .8s linear infinite}
    @keyframes video-loading-spin{to{transform:rotate(360deg)}}
    footer{padding:8px 18px;min-height:36px;color:#aeb3bd;font-size:12px;display:flex;align-items:center;gap:12px}
    #source-field[hidden]{display:none}
    button{background:none;border:0;color:#f5f5f5;text-decoration:underline;cursor:pointer;font:inherit}
    label{display:flex;align-items:center;gap:8px;margin-left:auto}
    footer label{margin-left:0}
    footer label:first-of-type{margin-left:auto}
    footer select{max-width:min(42vw,220px);padding:6px 8px;background:#17191e;color:#f5f5f5;border:1px solid #41444c;border-radius:4px}
    @media(max-width:640px){header{align-items:flex-start;flex-direction:column;gap:12px}form{width:100%}#media-id{width:min(190px,42vw)}.episode-field input{width:70px}#now-playing{padding-top:14px}video{min-height:45vh}}
  </style>
</head>
<body>
  <main>
    ${showForm ? `
    <header>
      <h1>VidSrc Player</h1>
      <form id="media-form">
        <label class="field" for="media-provider">Provider<select id="media-provider">${providerOptions}</select></label>
        <label class="field" for="media-type">Type<select id="media-type"><option value="movie"${selectedType === 'movie' ? ' selected' : ''}>Movie</option><option value="tv"${selectedType === 'tv' ? ' selected' : ''}>TV show</option></select></label>
        <label class="field" for="audio-language">Audio language<select id="audio-language"><option value="en"${selectedLanguage === 'en' ? ' selected' : ''}>English</option><option value="es"${selectedLanguage === 'es' ? ' selected' : ''}>Spanish</option><option value="fr"${selectedLanguage === 'fr' ? ' selected' : ''}>French</option><option value="de"${selectedLanguage === 'de' ? ' selected' : ''}>German</option><option value="it"${selectedLanguage === 'it' ? ' selected' : ''}>Italian</option><option value="pt"${selectedLanguage === 'pt' ? ' selected' : ''}>Portuguese</option><option value="ja"${selectedLanguage === 'ja' ? ' selected' : ''}>Japanese</option><option value="ko"${selectedLanguage === 'ko' ? ' selected' : ''}>Korean</option></select></label>
        <label class="field" for="subtitle-preference">Subtitles<select id="subtitle-preference"><option value="1"${selectedSubtitles === '1' ? ' selected' : ''}>On</option><option value="0"${selectedSubtitles === '0' ? ' selected' : ''}>Off</option></select></label>
        <label class="field" for="media-id"><span id="media-id-label">Media / provider ID</span><input id="media-id" name="id" required pattern="(?:tt[0-9]+|[0-9]+)" placeholder="IMDb, TMDB, or provider-specific ID" value="${escapeHtml(initialId)}"></label>
        <label class="field episode-field" for="season"${selectedType === 'tv' ? '' : ' hidden'}>Season<input id="season" type="number" min="1" step="1" value="${escapeHtml(initialSeason)}"></label>
        <label class="field episode-field" for="episode"${selectedType === 'tv' ? '' : ' hidden'}>Episode<input id="episode" type="number" min="1" step="1" value="${escapeHtml(initialEpisode)}"></label>
        <button type="submit">Play</button>
      </form>
    </header>` : ''}
    <div id="now-playing" hidden></div>
    <div id="video-container" hidden>
      <video id="video" controls playsinline hidden></video>
      <div id="video-loading" role="status" aria-label="Loading video" hidden></div>
    </div>
    <footer><span id="status">Enter an ID supported by the selected provider.</span> <button id="retry" hidden>Retry</button><label id="source-field" for="source">Source<select id="source" disabled><option value="">Auto</option></select></label><label for="quality">Quality<select id="quality" disabled><option value="-1">Auto</option></select></label><label for="subtitles">Subtitles<select id="subtitles" disabled><option value="">Off</option></select></label></footer>
  </main>
  <script src="https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js"></script>
  <script>
    const video = document.getElementById('video');
    const videoContainer = document.getElementById('video-container');
    const videoLoading = document.getElementById('video-loading');
    const status = document.getElementById('status');
    const retry = document.getElementById('retry');
    const quality = document.getElementById('quality');
    const subtitles = document.getElementById('subtitles');
    const sourceField = document.getElementById('source-field');
    const sourceSelect = document.getElementById('source');
    const form = document.getElementById('media-form');
    const providerInput = document.getElementById('media-provider');
    const typeInput = document.getElementById('media-type');
    const languageInput = document.getElementById('audio-language');
    const subtitlePreferenceInput = document.getElementById('subtitle-preference');
    const idInput = document.getElementById('media-id');
    const idLabel = document.getElementById('media-id-label');
    const seasonInput = document.getElementById('season');
    const episodeInput = document.getElementById('episode');
    const episodeFields = document.querySelectorAll('.episode-field');
    const nowPlaying = document.getElementById('now-playing');
    const initialMedia = ${JSON.stringify(playbackMedia)};
    let hls;
    let subtitleTrack;
    let selectedMedia;
    let requestGeneration = 0;
    let mediaRecoveryAttempted = false;
    function mediaQuery(media) {
      const query = new URLSearchParams({
        provider: media.providerId,
        type: media.type,
        id: media.id,
        lang: media.lang,
        sub: media.sub,
      });
      if (media.type === 'tv') {
        query.set('season', media.season);
        query.set('episode', media.episode);
      }
      return query.toString();
    }
    function fail(message) {
      videoLoading.hidden = true;
      status.textContent = message;
      retry.hidden = false;
    }
    function clearSubtitleOptions() {
      if (subtitleTrack) { subtitleTrack.remove(); subtitleTrack = null; }
      subtitles.replaceChildren(new Option('Off', ''));
      subtitles.disabled = true;
    }
    async function autoplay(generation) {
      if (generation !== requestGeneration) return;
      try {
        await video.play();
        status.textContent = '';
      } catch (_) {
        video.muted = true;
        try {
          await video.play();
          status.textContent = 'Playing muted. Unmute to hear audio.';
        } catch (_) {
          status.textContent = 'Autoplay was blocked. Press play to start.';
        }
      }
    }
    function start(media, sourceId = sourceSelect.value) {
      const generation = ++requestGeneration;
      videoLoading.hidden = false;
      mediaRecoveryAttempted = false;
      retry.hidden = true;
      status.textContent = 'Connecting to stream...';
      quality.replaceChildren(new Option('Auto', '-1'));
      quality.disabled = true;
      quality.title = 'Automatic quality selection';
      const manifestQuery = new URLSearchParams(mediaQuery(media));
      if (sourceId) manifestQuery.set('source', sourceId);
      try {
        if (window.Hls && Hls.isSupported()) {
          if (hls) hls.destroy();
          hls = new Hls();
          hls.loadSource('/manifest?' + manifestQuery);
          hls.attachMedia(video);
          const updateQualityLevels = () => {
            if (generation !== requestGeneration) return;
            const levels = hls.levels.map((level, index) => ({ level, index }))
              .sort((a, b) => (b.level.height || 0) - (a.level.height || 0));
            quality.replaceChildren(new Option('Auto', '-1'));
            for (const { level, index } of levels) {
              const resolution = level.height ? level.height + 'p' : 'Level ' + (index + 1);
              const bitrate = level.bitrate ? ' · ' + (level.bitrate / 1000000).toFixed(1) + ' Mbps' : '';
              quality.add(new Option(resolution + bitrate, String(index)));
            }
            quality.disabled = levels.length === 0;
            quality.title = levels.length ? 'Choose video quality' : 'No quality levels reported';
          };
          hls.on(Hls.Events.LEVELS_UPDATED, updateQualityLevels);
          hls.on(Hls.Events.MANIFEST_PARSED, () => {
            updateQualityLevels();
            autoplay(generation);
          });
          hls.on(Hls.Events.LEVEL_SWITCHED, (_, data) => {
            if (generation !== requestGeneration || Number(quality.value) !== -1) return;
            const level = hls.levels[data.level];
            quality.options[0].textContent = level?.height ? 'Auto (' + level.height + 'p)' : 'Auto';
          });
          hls.on(Hls.Events.ERROR, (_, data) => {
            if (generation !== requestGeneration || !data.fatal) return;
            if (data.details === Hls.ErrorDetails.MEDIA_SOURCE_REQUIRES_RESET && !mediaRecoveryAttempted) {
              mediaRecoveryAttempted = true;
              status.textContent = 'Recovering playback...';
              hls.recoverMediaError();
              return;
            }
            fail('Playback error: ' + data.details);
          });
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
          video.src = '/manifest?' + manifestQuery;
          quality.disabled = true;
          quality.title = 'Automatic quality selection is handled by the browser';
          video.addEventListener('loadedmetadata', () => autoplay(generation), { once: true });
        } else {
          throw new Error('This browser does not support HLS playback');
        }
        video.addEventListener('loadeddata', () => {
          if (generation === requestGeneration) status.textContent = '';
        }, { once: true });
      } catch (error) {
        fail('Unable to load stream: ' + error.message);
      }
    }
    async function loadSources(media, generation) {
      sourceField.hidden = true;
      sourceSelect.disabled = true;
      sourceSelect.replaceChildren(new Option('Auto', ''));
      try {
        const response = await fetch('/sources?' + mediaQuery(media));
        if (!response.ok) throw new Error('Source list request failed');
        const sources = await response.json();
        if (generation !== requestGeneration || !sources.length) return;
        for (const source of sources) {
          const option = new Option(source.label + (source.language ? ' (' + source.language + ')' : ''), source.id);
          sourceSelect.add(option);
        }
        sourceField.hidden = false;
        sourceSelect.disabled = false;
      } catch (_) {
        sourceField.hidden = true;
      }
    }
    quality.addEventListener('change', () => {
      if (!hls) return;
      const level = Number(quality.value);
      hls.currentLevel = level;
      if (level === -1) quality.options[0].textContent = 'Auto';
    });
    video.addEventListener('error', () => fail('Video playback failed: ' + (video.error?.message || 'unsupported media')));
    for (const event of ['loadstart', 'waiting', 'seeking']) {
      video.addEventListener(event, () => {
        if (!retry.hidden || video.hidden) return;
        videoLoading.hidden = false;
      });
    }
    for (const event of ['loadeddata', 'canplay', 'seeked', 'playing']) {
      video.addEventListener(event, () => {
        if (!video.seeking && video.readyState >= 3) videoLoading.hidden = true;
      });
    }
    video.addEventListener('ended', () => { videoLoading.hidden = true; });
    async function loadSubtitles(media, generation) {
      try {
        const response = await fetch('/subtitles?' + mediaQuery(media));
        if (!response.ok) throw new Error('Subtitle list request failed');
        const tracks = await response.json();
        if (generation !== requestGeneration) return;
        for (const track of tracks) {
          const option = document.createElement('option');
          option.value = track.id;
          option.textContent = track.language && track.language !== track.label
            ? track.label + ' (' + track.language + ')'
            : track.label;
          subtitles.appendChild(option);
        }
        subtitles.disabled = false;
        if (!tracks.length) subtitles.title = 'No subtitles available';
        if (media.sub === '1' && tracks.length) {
          const languageNames = { en: 'english', es: 'spanish', fr: 'french', de: 'german', it: 'italian', pt: 'portuguese', ja: 'japanese', ko: 'korean' };
          const preferredLanguage = languageNames[media.lang];
          const preferred = tracks.find((track) =>
            [track.lang, track.label].some((value) => String(value || '').toLowerCase() === preferredLanguage),
          ) || tracks[0];
          subtitles.value = preferred.id;
          subtitles.dispatchEvent(new Event('change'));
        }
      } catch (error) {
        subtitles.title = error.message;
      }
    }
    subtitles.addEventListener('change', () => {
      if (subtitleTrack) { subtitleTrack.remove(); subtitleTrack = null; }
      if (!subtitles.value) return;
      subtitleTrack = document.createElement('track');
      subtitleTrack.kind = 'subtitles';
      subtitleTrack.label = subtitles.selectedOptions[0].textContent;
      subtitleTrack.srclang = subtitles.selectedOptions[0].dataset.language || 'en';
      subtitleTrack.src = '/subtitle/' + encodeURIComponent(subtitles.value);
      subtitleTrack.default = true;
      video.appendChild(subtitleTrack);
      subtitleTrack.track.mode = 'showing';
      subtitleTrack.addEventListener('load', () => { subtitleTrack.track.mode = 'showing'; });
    });
    retry.addEventListener('click', () => {
      if (!selectedMedia) return;
      if (hls) { hls.destroy(); hls = null; }
      video.removeAttribute('src');
      video.load();
      start(selectedMedia, sourceSelect.value);
    });
    function playMedia(media) {
      selectedMedia = media;
      nowPlaying.textContent = (media.type === 'movie' ? 'Movie ' : 'TV ') + media.id + (media.type === 'tv' ? ' · S' + media.season + ' E' + media.episode : '');
      nowPlaying.hidden = false;
      videoContainer.hidden = false;
      video.hidden = false;
      video.pause();
      video.removeAttribute('src');
      video.load();
      if (hls) { hls.destroy(); hls = null; }
      clearSubtitleOptions();
      start(media);
      const generation = requestGeneration;
      loadSources(media, generation);
      loadSubtitles(media, generation);
    }
    sourceSelect.addEventListener('change', () => {
      if (!selectedMedia) return;
      if (hls) { hls.destroy(); hls = null; }
      video.pause();
      video.removeAttribute('src');
      video.load();
      start(selectedMedia, sourceSelect.value);
    });
    if (form) {
      providerInput.addEventListener('change', () => {
        const isOnlyPelis = providerInput.value === 'onlypelis';
        idLabel.textContent = isOnlyPelis ? 'TMDB ID' : 'Media / provider ID';
        idInput.placeholder = isOnlyPelis ? 'Numeric TMDB ID' : 'IMDb, TMDB, or provider-specific ID';
      });
      typeInput.addEventListener('change', () => {
        const isTv = typeInput.value === 'tv';
        for (const field of episodeFields) field.hidden = !isTv;
        seasonInput.required = isTv;
        episodeInput.required = isTv;
      });
      form.addEventListener('submit', (event) => {
        event.preventDefault();
        if (!form.reportValidity()) return;
        const media = {
          providerId: providerInput.value,
          type: typeInput.value,
          id: idInput.value.trim(),
          lang: languageInput.value,
          sub: subtitlePreferenceInput.value,
        };
        if (media.type === 'tv') {
          media.season = seasonInput.value;
          media.episode = episodeInput.value;
        }
        if (media.providerId !== 'vidsrcbuzz') {
          window.location.assign('/player?' + mediaQuery(media));
          return;
        }
        playMedia(media);
      });
      providerInput.dispatchEvent(new Event('change'));
      typeInput.dispatchEvent(new Event('change'));
    }
    if (initialMedia) playMedia(initialMedia);
  </script>
</body>
</html>`;
}

module.exports = { renderPlayerPage };