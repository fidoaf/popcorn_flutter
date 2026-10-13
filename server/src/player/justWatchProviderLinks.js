const JUSTWATCH_ORIGIN = 'https://www.justwatch.com';
const CACHE_TTL_MS = 5 * 60 * 1000;
const cache = new Map();
const searchPaths = { ES: 'buscar', BR: 'buscar', FR: 'rechercher', DE: 'suche', IT: 'cerca', NL: 'zoeken', US: 'search', GB: 'search', CA: 'search', AU: 'search' };

async function resolveJustWatchProviderLinks({ type, title, year, region, fetchImpl = fetch }) {
  const normalizedType = String(type || '').toLowerCase();
  const normalizedTitle = String(title || '').trim();
  const normalizedRegion = String(region || '').toUpperCase();
  if (!['movie', 'tv'].includes(normalizedType) || !normalizedTitle || normalizedTitle.length > 200 || !/^[A-Z]{2}$/.test(normalizedRegion)) {
    const error = new Error('Provide a valid media type, title and two-letter region');
    error.statusCode = 400;
    throw error;
  }

  const normalizedYear = /^\d{4}$/.test(String(year || '')) ? String(year) : '';
  const cacheKey = `${normalizedType}:${normalizedRegion}:${normalizedTitle.toLowerCase()}:${normalizedYear}`;
  const cached = cache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) return cached.links;

  const links = await fetchProviderLinks({ type: normalizedType, title: normalizedTitle, year: normalizedYear, region: normalizedRegion, fetchImpl });
  cache.set(cacheKey, { links, expiresAt: Date.now() + CACHE_TTL_MS });
  if (cache.size > 128) cache.delete(cache.keys().next().value);
  return links;
}

async function fetchProviderLinks({ type, title, year, region, fetchImpl }) {
  const regionPath = region.toLowerCase();
  const searchPath = searchPaths[region] || 'search';
  const searchUrl = new URL(`/${regionPath}/${searchPath}`, JUSTWATCH_ORIGIN);
  searchUrl.searchParams.set('q', year ? `${title} ${year}` : title);

  const searchHtml = await fetchHtml(searchUrl, fetchImpl);
  const titleUrl = findTitleUrl(searchHtml, { type, regionPath, title, year });
  if (!titleUrl) return {};

  const titleHtml = await fetchHtml(titleUrl, fetchImpl);
  return extractOfferLinks(titleHtml);
}

async function fetchHtml(url, fetchImpl) {
  const response = await fetchImpl(url, {
    headers: { Accept: 'text/html', 'User-Agent': 'Mozilla/5.0 Popcorn/1.0' },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`JustWatch returned HTTP ${response.status}`);
  return response.text();
}

function findTitleUrl(html, { type, regionPath, title, year }) {
  const candidates = [];
  const anchors = /<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let match;
  while ((match = anchors.exec(html)) !== null) {
    const url = safeJustWatchTitleUrl(match[1], regionPath, type);
    if (!url || candidates.some((candidate) => candidate.url.href === url.href)) continue;
    const text = decodeHtml(match[2].replace(/<[^>]*>/g, ' ')).replace(/\s+/g, ' ').trim();
    candidates.push({ url, text });
  }

  if (candidates.length === 0) return null;
  const expectedTitle = normalizeTitle(title);
  const exact = candidates.find((candidate) => normalizeTitle(candidate.text.replace(/\(?\d{4}\)?/g, '')) === expectedTitle);
  if (exact) return exact.url;
  if (year) {
    const matchingYear = candidates.find((candidate) => candidate.text.includes(year));
    if (matchingYear) return matchingYear.url;
  }
  return candidates[0].url;
}

function safeJustWatchTitleUrl(value, regionPath, type) {
  let url;
  try {
    url = new URL(decodeHtml(value), JUSTWATCH_ORIGIN);
  } catch {
    return null;
  }
  if (url.origin !== JUSTWATCH_ORIGIN || url.pathname.split('/')[1] !== regionPath) return null;
  const segments = url.pathname.split('/');
  const isMovie = segments.includes('pelicula') || segments.includes('movie');
  const isTv = segments.includes('serie') || segments.includes('tv-show') || segments.includes('tv-series');
  return type === 'movie' && isMovie || type === 'tv' && isTv ? url : null;
}

function extractOfferLinks(html) {
  const links = {};
  const anchors = /<a\b[^>]*href=["']([^"']+)["'][^>]*>/gi;
  let match;
  while ((match = anchors.exec(html)) !== null) {
    let url;
    try {
      url = new URL(decodeHtml(match[1]));
    } catch {
      continue;
    }
    if (url.protocol !== 'https:' || !['e.justwatch.com', 'click.justwatch.com'].includes(url.hostname) || url.pathname !== '/a') continue;
    const providerId = providerIdFromClickout(url.searchParams.get('cx'));
    if (providerId && !links[providerId]) links[providerId] = url.href;
  }
  return links;
}

function providerIdFromClickout(encodedContext) {
  if (!encodedContext) return null;
  try {
    const context = JSON.parse(Buffer.from(encodedContext, 'base64').toString('utf8'));
    const provider = context.data?.find((entry) => Number.isInteger(entry.data?.providerId));
    return provider ? String(provider.data.providerId) : null;
  } catch {
    return null;
  }
}

function normalizeTitle(value) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

function decodeHtml(value) {
  return value.replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>');
}

module.exports = { resolveJustWatchProviderLinks };