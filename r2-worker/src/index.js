/**
 * R2 Upload/Download Worker fuer WarteListe Pro Dokumente.
 * 
 * POST /upload?key=praxen/xxx/patienten/yyy/file.jpg  → Upload
 * GET  /file/praxen/xxx/patienten/yyy/file.jpg         → Download
 * DELETE /file/praxen/xxx/patienten/yyy/file.jpg       → Delete
 */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    // Upload: POST /upload?key=path/to/file
    if (request.method === 'POST' && url.pathname === '/upload') {
      const key = url.searchParams.get('key');
      if (!key) return new Response('Missing key', { status: 400, headers: cors });

      const body = await request.arrayBuffer();
      const contentType = request.headers.get('Content-Type') || 'application/octet-stream';

      await env.BUCKET.put(key, body, {
        httpMetadata: { contentType },
      });

      const fileUrl = `${url.origin}/file/${key}`;
      return new Response(JSON.stringify({ url: fileUrl, key }), {
        status: 200,
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    // Download: GET /file/path/to/file
    if (request.method === 'GET' && url.pathname.startsWith('/file/')) {
      const key = url.pathname.slice(6); // Remove '/file/'
      const object = await env.BUCKET.get(key);

      if (!object) {
        return new Response('Not found', { status: 404, headers: cors });
      }

      const headers = new Headers(cors);
      object.writeHttpMetadata(headers);
      headers.set('Cache-Control', 'public, max-age=86400');

      return new Response(object.body, { headers });
    }

    // Delete: DELETE /file/path/to/file
    if (request.method === 'DELETE' && url.pathname.startsWith('/file/')) {
      const key = url.pathname.slice(6);
      await env.BUCKET.delete(key);
      return new Response('Deleted', { status: 200, headers: cors });
    }

    return new Response('WarteListe Pro R2 API', { status: 200, headers: cors });
  },
};
