const http = require('http');
const https = require('https');

// Thin wrapper over Node's http/https that picks the right client from the URL
// scheme, so callers don't repeat that branching everywhere.
function get(url, options, callback) {
  const client = url.startsWith('https') ? https : http;
  return client.get(url, options, callback);
}

module.exports = { get };
