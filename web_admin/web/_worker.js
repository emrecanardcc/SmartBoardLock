export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // If request starts with /backend/
    if (url.pathname.startsWith('/backend/')) {
      const targetUrl = 'http://130-61-78-192.sslip.io' + url.pathname + url.search;

      // Handle CORS preflight (OPTIONS)
      if (request.method === 'OPTIONS') {
        return new Response(null, {
          status: 204,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
            'Access-Control-Allow-Headers': '*',
            'Access-Control-Max-Age': '86400',
          },
        });
      }

      // Handle WebSocket upgrade for Supabase realtime
      if (request.headers.get('Upgrade') === 'websocket') {
        return fetch(targetUrl, request);
      }

      const proxyHeaders = new Headers(request.headers);
      proxyHeaders.set('Host', '130-61-78-192.sslip.io');

      const proxyRequest = new Request(targetUrl, {
        method: request.method,
        headers: proxyHeaders,
        body: ['GET', 'HEAD'].includes(request.method) ? null : request.body,
        redirect: 'manual',
      });

      try {
        const response = await fetch(proxyRequest);

        const responseHeaders = new Headers(response.headers);
        responseHeaders.set('Access-Control-Allow-Origin', '*');
        responseHeaders.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
        responseHeaders.set('Access-Control-Allow-Headers', '*');

        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: responseHeaders,
        });
      } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), {
          status: 502,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        });
      }
    }

    // Default: serve static assets from Cloudflare Pages
    return env.ASSETS.fetch(request);
  },
};
