const { DEFAULT_PROVIDER_ID } = require('./providerRegistry');

function mediaFromQuery(params, providers) {
  const providerId = params.get('provider') || DEFAULT_PROVIDER_ID;
  providers.get(providerId);

  const type = (params.get('type') || 'movie').toLowerCase();
  const id = (params.get('id') || params.get('imdbId') || '').trim();
  const lang = (params.get('lang') || 'en').trim().toLowerCase();
  const sub = params.get('sub') || '1';
  if (!['movie', 'tv'].includes(type) || !/^(tt\d+|\d+)$/.test(id)) {
    throw badRequest('Provide a valid movie/TV type and IMDb or TMDB ID');
  }
  if (!/^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$/.test(lang)) {
    throw badRequest('Language must be a valid language code, for example en');
  }
  if (!['0', '1'].includes(sub)) {
    throw badRequest('Subtitles must be set to 0 or 1');
  }

  const media = { providerId, type, id, lang, sub };
  if (type === 'tv') {
    const season = params.get('season');
    const episode = params.get('episode');
    if (!/^[1-9]\d*$/.test(season || '') || !/^[1-9]\d*$/.test(episode || '')) {
      throw badRequest('TV shows require positive season and episode numbers');
    }
    media.season = season;
    media.episode = episode;
  } else {
    media.season = '0';
    media.episode = '0';
  }
  return media;
}

function badRequest(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

module.exports = { mediaFromQuery };