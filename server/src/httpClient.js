const http = require('http');
const https = require('https');

const REQUEST_TIMEOUT_MS = 15000;

// Thin wrapper over Node's http/https that picks the right client from the URL
// scheme, so callers don't repeat that branching everywhere.
function get(url, options, callback) {
  const client = url.startsWith('https') ? https : http;
  const request = client.get(url, options, callback);

  request.on('timeout', () => {
    request.destroy(new Error('Upstream request timed out'));
  });
  request.setTimeout(REQUEST_TIMEOUT_MS);

  return request;
}

module.exports = { get, REQUEST_TIMEOUT_MS };
