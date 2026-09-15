// Parsing and identity of a media request, decoupled from where the stream
// actually comes from. `SourceProvider` isolates the embed-URL scheme so a new
// provider can be added without touching the rest of the server (Open/Closed).
function parseMediaParams(searchParams) {
  const imdbId = searchParams.get('id') || searchParams.get('imdbId');
  const type = (searchParams.get('type') || 'movie').toLowerCase() === 'tv' ? 'tv' : 'movie';
  const season = Math.max(1, Number(searchParams.get('season')) || 1);
  const episode = Math.max(1, Number(searchParams.get('episode')) || 1);
  return { imdbId, type, season, episode };
}

function cacheKey({ imdbId, type, season, episode }) {
  return type === 'tv' ? `tv:${imdbId}:${season}:${episode}` : `movie:${imdbId}`;
}

class VidsrcProvider {
  buildSourceUrl({ imdbId, type, season, episode }) {
    if (type === 'tv') {
      return `https://vidsrc.ir/embed/tv/${imdbId}/${season}/${episode}`;
    }
    return `https://vidsrc.ir/embed/movie/${imdbId}`;
  }
}

module.exports = { parseMediaParams, cacheKey, VidsrcProvider };
