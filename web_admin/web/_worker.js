export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Candidate origins to route to Oracle VM (resolving to 130.61.78.192)
    const origins = [
      '130.61.78.192.nip.io',
      '130-61-78-192.nip.io',
      '130.61.78.192.traefik.me'
    ];

    // Check if request is for binary downloads (.apk, .exe, .zip, .msi) or /downloads/
    const isBinaryDownload =
      url.pathname.endsWith('.apk') ||
      url.pathname.endsWith('.exe') ||
      url.pathname.endsWith('.zip') ||
      url.pathname.endsWith('.msi') ||
      url.pathname.startsWith('/downloads/');

    // 1. Binary Download Proxy (APK, EXE, ZIP)
    if (isBinaryDownload) {
      if (request.method === 'OPTIONS') {
        return new Response(null, {
          status: 204,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
            'Access-Control-Allow-Headers': '*',
            'Access-Control-Max-Age': '86400',
          },
        });
      }

      // If URL was /downloads/filename.apk, strip /downloads prefix to reach VM root
      const targetPath = url.pathname.startsWith('/downloads/')
        ? url.pathname.replace(/^\/downloads/, '') || '/'
        : url.pathname;

      for (const origin of origins) {
        const targetUrl = `http://${origin}${targetPath}${url.search}`;
        const proxyHeaders = new Headers(request.headers);
        proxyHeaders.set('Host', origin);

        try {
          const response = await fetch(targetUrl, {
            method: request.method,
            headers: proxyHeaders,
          });

          if (response.status === 530) continue; // Origin DNS Error 1016

          if (response.ok || response.status === 206) {
            const filename = targetPath.split('/').pop() || 'download';
            const responseHeaders = new Headers(response.headers);
            responseHeaders.set('Access-Control-Allow-Origin', '*');
            responseHeaders.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
            responseHeaders.set('Access-Control-Expose-Headers', 'Content-Length, Content-Disposition, Content-Type, Accept-Ranges');
            responseHeaders.set('Content-Disposition', `attachment; filename="${filename}"`);

            if (filename.endsWith('.apk')) {
              responseHeaders.set('Content-Type', 'application/vnd.android.package-archive');
            } else if (filename.endsWith('.exe')) {
              responseHeaders.set('Content-Type', 'application/octet-stream');
            } else if (filename.endsWith('.zip')) {
              responseHeaders.set('Content-Type', 'application/zip');
            }

            return new Response(response.body, {
              status: response.status,
              statusText: response.statusText,
              headers: responseHeaders,
            });
          }
        } catch (err) {
          // fallback to next origin
        }
      }

      return new Response('Dosya bulunamadi (404)', {
        status: 404,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    // 2. Supabase Backend API & Realtime Proxy (/backend/)
    if (url.pathname.startsWith('/backend/')) {
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
        const wsTarget = `http://${origins[0]}${url.pathname}${url.search}`;
        const wsHeaders = new Headers(request.headers);
        wsHeaders.set('Host', origins[0]);
        return fetch(wsTarget, {
          method: request.method,
          headers: wsHeaders,
        });
      }

      const bodyBuffer = ['GET', 'HEAD'].includes(request.method)
        ? null
        : await request.arrayBuffer();

      let lastResponse = null;
      let lastError = null;

      for (const origin of origins) {
        const targetUrl = `http://${origin}${url.pathname}${url.search}`;
        const proxyHeaders = new Headers(request.headers);
        proxyHeaders.set('Host', origin);

        const proxyRequest = new Request(targetUrl, {
          method: request.method,
          headers: proxyHeaders,
          body: bodyBuffer,
          redirect: 'manual',
        });

        try {
          const response = await fetch(proxyRequest);

          // If Cloudflare returns 530 (Origin DNS Error 1016), try next origin
          if (response.status === 530) {
            lastResponse = response;
            continue;
          }

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
          lastError = err;
        }
      }

      // If all origins failed
      if (lastResponse) {
        return lastResponse;
      }

      return new Response(JSON.stringify({ error: lastError ? lastError.message : 'Origin unreachable' }), {
        status: 502,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    // Default: serve static assets from Cloudflare Pages
    return env.ASSETS.fetch(request);
  },
};
