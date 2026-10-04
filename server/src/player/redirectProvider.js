class RedirectProvider {
  constructor({ id, label, scheme = 'https', host, path = '', parameters = {} }) {
    if (typeof host !== 'string' || !host || typeof path !== 'string') {
      throw new TypeError(`Provider ${label || id} requires a host and path`);
    }
    if (!parameters || typeof parameters !== 'object' || Array.isArray(parameters)) {
      throw new TypeError(`Provider ${label || id} parameters must be an object`);
    }
    const baseUrl = new URL(`${scheme}://${host}`);
    if (!['http:', 'https:'].includes(baseUrl.protocol)) {
      throw new TypeError(`Provider ${label || id} must use HTTP or HTTPS`);
    }
    if (path && (!path.startsWith('/') || path.startsWith('//'))) {
      throw new TypeError(`Provider ${label || id} path must be an absolute path`);
    }
    this.id = id;
    this.label = label;
    this.origin = baseUrl.origin;
    this.path = path;
    this.parameters = parameters;
  }

  embedUrl(media) {
    const values = {
      id: String(media.id),
      type: String(media.type),
      season: media.type === 'tv' ? String(media.season) : '',
      episode: media.type === 'tv' ? String(media.episode) : '',
      language: media.lang || 'en',
      subtitles: media.sub ?? '1',
    };
    const substitute = (template, encodeValues = false) => String(template).replace(/\{([^{}]+)\}/g, (placeholder, key) => {
      if (!Object.hasOwn(values, key)) throw new TypeError(`Unsupported provider placeholder: ${placeholder}`);
      return encodeValues ? encodeURIComponent(values[key]) : values[key];
    });
    const expandedPath = substitute(this.path, true);
    const normalizedPath = `/${expandedPath.split('/').filter(Boolean).join('/')}`;
    const url = new URL(this.origin);
    url.pathname = normalizedPath;
    for (const [key, value] of Object.entries(this.parameters)) {
      const resolvedValue = substitute(value);
      if (resolvedValue === '' && /\{(?:season|episode)\}/.test(value)) continue;
      url.searchParams.set(substitute(key), resolvedValue);
    }
    return url;
  }
}

module.exports = { RedirectProvider };