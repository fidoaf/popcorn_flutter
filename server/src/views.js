// HTML page builders. Presentation lives here and nowhere else, so route
// handlers never concatenate markup inline.

function playerPage(media, token) {
  const imdbId = media.imdbId;
  const mediaSuffix =
    media.type === 'tv'
      ? '&type=tv&season=' + media.season + '&episode=' + media.episode
      : '&type=movie';
  const mediaLabel =
    media.type === 'tv'
      ? imdbId + ' \u00b7 S' + media.season + 'E' + media.episode
      : imdbId;

  return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <title>HLS Player - ${mediaLabel}</title>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { background: #000; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
      .container { display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
      video { width: 100%; max-width: 1280px; height: auto; max-height: 720px; background: #000; border-radius: 8px; }
      .info { color: #999; margin-top: 20px; text-align: center; font-size: 11px; word-break: break-all; }
      code { background: #1a1a1a; padding: 2px 4px; border-radius: 3px; display: inline-block; }
      .status { color: #666; font-size: 12px; margin-top: 10px; }
      .error {
        display: none;
        white-space: pre-wrap;
        word-break: break-all;
        text-align: left;
        color: #ff6b6b;
        background: #1a1a1a;
        border: 1px solid #3a1a1a;
        border-radius: 8px;
        padding: 12px 14px;
        margin: 16px auto 0;
        max-width: 1000px;
        width: 100%;
        font-family: 'Cascadia Code', Consolas, monospace;
        font-size: 12px;
        line-height: 1.5;
      }
      .error.show { display: block; }
    </style>
  </head>
  <body>
    <div class="container">
      <video id="video" controls autoplay></video>
      <div class="info">
        <p>ID: <code>${mediaLabel}</code></p>
        <p class="status" id="status">Loading...</p>
        <pre class="error" id="error"></pre>
      </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@1.4.0/dist/hls.min.js"><\/script>
    <script>
      (function () {
        const imdbId = ${JSON.stringify(imdbId)};
        const token = ${JSON.stringify(token)};
        const video = document.getElementById('video');
        const statusEl = document.getElementById('status');
        const errorEl = document.getElementById('error');
        const proxiedM3u8 = '/proxy-m3u8?id=' + encodeURIComponent(imdbId) + (token ? '&token=' + encodeURIComponent(token) : '') + ${JSON.stringify(mediaSuffix)};

        // Re-request the manifest to surface the server's JSON error payload,
        // which hls.js/native playback do not expose.
        async function fetchServerError() {
          try {
            const resp = await fetch(proxiedM3u8, {
              headers: token ? { Authorization: 'Bearer ' + token } : {},
            });
            const text = await resp.text();
            let body;
            try { body = JSON.parse(text); } catch (_) { body = text; }
            return { status: resp.status, body: body };
          } catch (e) {
            return { status: 0, body: String(e) };
          }
        }

        function showError(title, detail) {
          statusEl.textContent = title;
          errorEl.textContent = typeof detail === 'string' ? detail : JSON.stringify(detail, null, 2);
          errorEl.classList.add('show');
        }

        if (window.Hls && Hls.isSupported()) {
          const hls = new Hls({ debug: false });

          hls.on(Hls.Events.MANIFEST_LOADING, () => statusEl.textContent = 'Loading manifest...');
          hls.on(Hls.Events.MANIFEST_PARSED, () => {
            statusEl.textContent = 'Ready';
            video.play().catch(() => {});
          });
          hls.on(Hls.Events.ERROR, async function (event, data) {
            if (!data.fatal) {
              statusEl.textContent = 'Warning: ' + (data.details || data.type);
              return;
            }
            console.error('[hls] Fatal Error:', data);
            const info = await fetchServerError();
            const respText = data.response && data.response.data ? String(data.response.data) : null;
            showError(
              'Error: ' + (data.details || data.type) + ' (HTTP ' + info.status + ')',
              info.body || respText || data,
            );
          });

          hls.loadSource(proxiedM3u8);
          hls.attachMedia(video);
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
          statusEl.textContent = 'Loading with native playback...';
          video.src = proxiedM3u8;
          video.addEventListener('loadedmetadata', function () {
            statusEl.textContent = 'Ready';
            video.play().catch(() => {});
          });
          video.addEventListener('error', async function () {
            const info = await fetchServerError();
            showError('Playback error (HTTP ' + info.status + ')', info.body);
          });
        } else {
          statusEl.textContent = 'HLS not supported';
        }
      })();
    <\/script>
  </body>
</html>`;
}

function landingPage() {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
    <title>Popcorn</title>
    <style>
      :root {
        --background: #0F171E;
        --background-top: #16212B;
        --surface: #1A242F;
        --accent: #1FAAE2;
        --text-primary: #FFFFFF;
        --text-secondary: #9BA9B4;
      }
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body {
        min-height: 100vh;
        background: linear-gradient(180deg, var(--background-top) 0%, var(--background) 60%);
        color: var(--text-primary);
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        display: flex;
        flex-direction: column;
        align-items: center;
      }
      header {
        width: 100%;
        max-width: 1100px;
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 24px 20px;
      }
      header img { width: 40px; height: 40px; border-radius: 8px; }
      header h1 { font-size: 22px; font-weight: 800; letter-spacing: 0.5px; }
      .hero {
        width: 100%;
        max-width: 1100px;
        padding: 40px 20px 24px;
      }
      .hero h2 { font-size: 32px; font-weight: 800; line-height: 1.1; }
      .hero p { color: var(--text-secondary); font-size: 15px; margin-top: 10px; max-width: 560px; }
      .search {
        width: 100%;
        max-width: 1100px;
        padding: 8px 20px 40px;
      }
      form {
        display: flex;
        gap: 10px;
        background: var(--surface);
        border: 1px solid rgba(155, 169, 180, 0.25);
        border-radius: 24px;
        padding: 8px 8px 8px 18px;
        align-items: center;
      }
      form:focus-within { border-color: var(--accent); }
      .search svg { flex: 0 0 auto; }
      input {
        flex: 1 1 auto;
        background: transparent;
        border: none;
        outline: none;
        color: var(--text-primary);
        font-size: 15px;
      }
      input::placeholder { color: var(--text-secondary); }
      button {
        flex: 0 0 auto;
        background: var(--accent);
        color: #06202B;
        border: none;
        border-radius: 20px;
        padding: 10px 22px;
        font-size: 14px;
        font-weight: 700;
        cursor: pointer;
      }
      button:hover { filter: brightness(1.05); }
      select {
        flex: 0 0 auto;
        background: var(--surface);
        color: var(--text-primary);
        border: 1px solid rgba(155, 169, 180, 0.25);
        border-radius: 20px;
        padding: 10px 12px;
        font-size: 14px;
        cursor: pointer;
      }
      .ep { display: flex; gap: 10px; margin-top: 12px; }
      .ep input {
        background: var(--surface);
        border: 1px solid rgba(155, 169, 180, 0.25);
        border-radius: 16px;
        padding: 10px 16px;
        width: 140px;
        color: var(--text-primary);
      }
      .hidden { display: none; }
      .hint { color: var(--text-secondary); font-size: 13px; margin-top: 12px; text-align: center; }
      .hint a { color: var(--accent); text-decoration: none; }
    </style>
  </head>
  <body>
    <header>
      <img src="/favicon.ico" alt="Popcorn">
      <h1>Popcorn</h1>
    </header>
    <section class="hero">
      <h2>Watch movies &amp; shows</h2>
      <p>Enter an IMDb ID to start streaming instantly.</p>
    </section>
    <section class="search">
      <form onsubmit="return goPlay(event)">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#9BA9B4" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
        <input id="imdb" type="text" placeholder="IMDb ID (e.g. tt1300854)" autocomplete="off" autofocus>
        <select id="type" onchange="onTypeChange()">
          <option value="movie">Movie</option>
          <option value="tv">TV</option>
        </select>
        <button type="submit">Play</button>
      </form>
      <div class="ep hidden" id="epRow">
        <input id="season" type="number" min="1" value="1" placeholder="Season">
        <input id="episode" type="number" min="1" value="1" placeholder="Episode">
      </div>
      <p class="hint">Try a <a href="/player?id=tt1300854&type=movie">movie</a> or a <a href="/player?id=tt0944947&type=tv&season=1&episode=1">TV episode</a></p>
    </section>
    <script>
      function onTypeChange() {
        const isTv = document.getElementById('type').value === 'tv';
        document.getElementById('epRow').classList.toggle('hidden', !isTv);
      }
      function goPlay(e) {
        e.preventDefault();
        const id = document.getElementById('imdb').value.trim();
        if (!id) return false;
        const type = document.getElementById('type').value;
        let target = '/player?id=' + encodeURIComponent(id) + '&type=' + type;
        if (type === 'tv') {
          const s = document.getElementById('season').value || '1';
          const ep = document.getElementById('episode').value || '1';
          target += '&season=' + encodeURIComponent(s) + '&episode=' + encodeURIComponent(ep);
        }
        window.location.href = target;
        return false;
      }
    <\/script>
  </body>
</html>`;
}

module.exports = { playerPage, landingPage };
