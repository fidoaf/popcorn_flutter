// Small helpers to write consistent HTTP responses so handlers stay focused on
// their logic instead of repeating headers and JSON serialization.
function sendJson(res, statusCode, payload, extraHeaders = {}) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json', ...extraHeaders });
  res.end(JSON.stringify(payload));
}

function sendHtml(res, statusCode, html) {
  res.writeHead(statusCode, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(html);
}

module.exports = { sendJson, sendHtml };
