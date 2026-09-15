// Pure transformation: rewrites the segment/child URLs inside an HLS manifest so
// every entry is fetched back through this server's proxy. No I/O here, which
// keeps it trivially testable.
function rewriteManifest(body, sourceUrl, { proxyPath = '/proxy-stream', tokenQuery = '' } = {}) {
  const baseUrl = sourceUrl.substring(0, sourceUrl.lastIndexOf('/') + 1);
  const domain = new URL(sourceUrl).origin;

  return body
    .split('\n')
    .map((line) => {
      if (line.startsWith('#') || !line.trim()) return line;

      let fullUrl;
      if (line.startsWith('http://') || line.startsWith('https://')) {
        fullUrl = line;
      } else if (line.startsWith('/')) {
        fullUrl = domain + line;
      } else {
        fullUrl = new URL(line, baseUrl).href;
      }

      return proxyPath + '?url=' + encodeURIComponent(fullUrl) + tokenQuery;
    })
    .join('\n');
}

module.exports = { rewriteManifest };
