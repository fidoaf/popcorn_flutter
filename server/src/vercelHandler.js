const { createServer } = require('../server');

let playerServer;

function handler(request, response) {
  const url = new URL(request.url || '/', 'http://localhost');
  const forwardedPath = url.searchParams.get('__vercel_route');
  if (forwardedPath && forwardedPath.startsWith('/')) {
    url.searchParams.delete('__vercel_route');
    url.pathname = forwardedPath;
  } else if (url.pathname === '/api') {
    url.pathname = '/';
  } else if (url.pathname.startsWith('/api/')) {
    url.pathname = url.pathname.slice('/api'.length) || '/';
  }
  request.url = `${url.pathname}${url.search}`;

  playerServer ||= createServer();
  playerServer.emit('request', request, response);
}

module.exports = handler;