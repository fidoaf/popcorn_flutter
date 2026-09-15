// Zero-dependency structured logger. Every module gets a namespaced instance so
// output is greppable by layer, and request-scoped children carry a correlation
// id so a single request can be traced end-to-end across modules.
const LEVELS = { debug: 10, info: 20, warn: 30, error: 40, silent: 100 };

function resolveThreshold(level) {
  const name = String(level || process.env.LOG_LEVEL || 'debug').toLowerCase();
  return LEVELS[name] ?? LEVELS.debug;
}

// Serializes metadata defensively: truncates long strings, tags buffers, and
// survives circular references so logging can never crash a request.
function formatMeta(meta) {
  if (meta === undefined) return '';
  const seen = new WeakSet();
  const replacer = (_key, value) => {
    if (typeof value === 'string' && value.length > 500) {
      return value.slice(0, 500) + `…(+${value.length - 500} chars)`;
    }
    if (Buffer.isBuffer(value)) return `<Buffer ${value.length} bytes>`;
    if (value instanceof Error) {
      return { name: value.name, message: value.message, code: value.code, stack: value.stack };
    }
    if (typeof value === 'object' && value !== null) {
      if (seen.has(value)) return '[Circular]';
      seen.add(value);
    }
    return value;
  };
  try {
    return ' ' + JSON.stringify(meta, replacer);
  } catch (_) {
    return ' ' + String(meta);
  }
}

function createLogger(namespace, options = {}) {
  const threshold = resolveThreshold(options.level);

  const emit = (level, sink, message, meta) => {
    if (LEVELS[level] < threshold) return;
    const line =
      `${new Date().toISOString()} ${level.toUpperCase().padEnd(5)} ` +
      `[${namespace}] ${message}${formatMeta(meta)}`;
    sink(line);
  };

  return {
    namespace,
    debug: (message, meta) => emit('debug', console.log, message, meta),
    info: (message, meta) => emit('info', console.log, message, meta),
    warn: (message, meta) => emit('warn', console.warn, message, meta),
    error: (message, meta) => emit('error', console.error, message, meta),
    child: (suffix) => createLogger(`${namespace}:${suffix}`, options),
  };
}

module.exports = { createLogger, LEVELS };
