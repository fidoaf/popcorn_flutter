const { DEFAULT_PROVIDER_ID } = require('./providerRegistry');

function mediaFromQuery(params, providers) {
  const providerId = params.get('provider') || DEFAULT_PROVIDER_ID;
  providers.get(providerId);

  const type = (params.get('type') || 'movie').toLowerCase();
  const id = (params.get('id') || params.get('imdbId') || '').trim();
  if (!['movie', 'tv'].includes(type) || !/^(tt\d+|\d+)$/.test(id)) {
    throw badRequest('Provide a valid movie/TV type and IMDb or TMDB ID');
  }

  const media = { providerId, type, id };
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