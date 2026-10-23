async function fetchIntroDb(params, fetchImpl = fetch) {
  const id = params.get('id') || '';
  const type = params.get('type');
  const duration = params.get('duration_ms');
  if (!/^(tt\d+|[1-9]\d*)$/.test(id) || !['movie', 'tv'].includes(type) ||
      !/^[1-9]\d*$/.test(duration || '') || !Number.isSafeInteger(Number(duration))) {
    throw badRequest('Invalid IntroDB media or duration');
  }
  const url = new URL('https://api.theintrodb.org/v4/media');
  url.searchParams.set(id.startsWith('tt') ? 'imdb_id' : 'tmdb_id', id);
  url.searchParams.set('duration_ms', duration);
  if (type === 'tv') {
    for (const key of ['season', 'episode']) {
      const value = params.get(key);
      if (!/^[1-9]\d*$/.test(value || '')) throw badRequest('Invalid IntroDB episode');
      url.searchParams.set(key, value);
    }
  }
  const response = await fetchImpl(url, { signal: AbortSignal.timeout(10000) });
  if (response.status === 404) return { intro: [], credits: [] };
  if (!response.ok) throw new Error(`IntroDB request failed (${response.status})`);
  return response.json();
}

function badRequest(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

module.exports = { fetchIntroDb };
