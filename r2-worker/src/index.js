/**
 * R2 Upload/Download Worker fuer WarteListe Pro Dokumente.
 *
 * Security:
 *  - Alle mutierenden Requests (POST, DELETE) verlangen gueltiges Firebase ID Token (Authorization: Bearer ...).
 *  - Pfad (praxen/{praxisId}/...) muss zu den praxisIds des eingeloggten Users passen (aus Firestore).
 *  - CORS beschraenkt auf erlaubte Origins.
 *  - Max Upload: 25 MB.
 *
 * POST   /upload?key=praxen/xxx/patienten/yyy/file.jpg  -> Upload  (auth + path check)
 * GET    /file/praxen/xxx/patienten/yyy/file.jpg         -> Download (auth + path check)
 * DELETE /file/praxen/xxx/patienten/yyy/file.jpg         -> Delete   (auth + path check)
 */

const FIREBASE_PROJECT_ID = 'warteliste-pro';
const JWK_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const MAX_UPLOAD_BYTES = 25 * 1024 * 1024; // 25 MB

const ALLOWED_ORIGINS = new Set([
  'https://warteliste-pro.pages.dev',
  'https://warteliste-pro.web.app',
  'https://warteliste-pro.firebaseapp.com',
  'http://localhost:5000',
  'http://localhost:8080',
  'http://localhost:3000',
]);

// --------- CORS ---------
function corsHeaders(request) {
  const origin = request.headers.get('Origin') || '';
  const allow = ALLOWED_ORIGINS.has(origin) ? origin : 'https://warteliste-pro.pages.dev';
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

function jsonResponse(body, status, cors) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

// --------- JWK Cache (in-memory pro Worker-Instanz) ---------
let jwkCache = null;
let jwkCacheTime = 0;
const JWK_TTL_MS = 60 * 60 * 1000; // 1h

async function getJwks() {
  if (jwkCache && Date.now() - jwkCacheTime < JWK_TTL_MS) return jwkCache;
  const resp = await fetch(JWK_URL);
  if (!resp.ok) throw new Error('JWK fetch failed');
  jwkCache = await resp.json();
  jwkCacheTime = Date.now();
  return jwkCache;
}

function b64urlDecode(str) {
  const pad = str.length % 4 === 0 ? '' : '='.repeat(4 - (str.length % 4));
  const b64 = (str + pad).replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function b64urlDecodeToString(str) {
  return new TextDecoder().decode(b64urlDecode(str));
}

async function verifyFirebaseIdToken(token) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Invalid JWT');

  const header = JSON.parse(b64urlDecodeToString(parts[0]));
  const payload = JSON.parse(b64urlDecodeToString(parts[1]));

  if (header.alg !== 'RS256') throw new Error('Invalid alg');
  if (payload.aud !== FIREBASE_PROJECT_ID) throw new Error('Invalid aud');
  if (payload.iss !== `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`) throw new Error('Invalid iss');
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp < now) throw new Error('Token expired');
  if (payload.iat > now + 60) throw new Error('Token from future');
  if (!payload.sub) throw new Error('No sub');

  const jwks = await getJwks();
  // jwks can be JWK-set ({keys:[...]}) or flat x509 dict.
  let jwk = null;
  if (jwks.keys && Array.isArray(jwks.keys)) {
    jwk = jwks.keys.find((k) => k.kid === header.kid);
  }
  if (!jwk) throw new Error('Unknown kid');

  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );

  const signedData = new TextEncoder().encode(parts[0] + '.' + parts[1]);
  const signature = b64urlDecode(parts[2]);

  const valid = await crypto.subtle.verify(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    signature,
    signedData,
  );
  if (!valid) throw new Error('Invalid signature');
  return payload;
}

// --------- Firestore User Lookup ---------
async function getUserPraxisIds(uid, idToken) {
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/users/${uid}`;
  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${idToken}` },
  });
  if (!resp.ok) return [];
  const doc = await resp.json();
  const fields = doc.fields || {};
  const praxisId = fields.praxisId?.stringValue;
  const praxisIdsArr = fields.praxisIds?.arrayValue?.values || [];
  const praxisIds = praxisIdsArr.map((v) => v.stringValue).filter(Boolean);
  const all = new Set(praxisIds);
  if (praxisId) all.add(praxisId);
  return [...all];
}

// --------- Path Validation ---------
function extractPraxisId(key) {
  // Expected: praxen/{praxisId}/patienten/{patientId}/{file}
  if (!key || key.includes('..') || key.startsWith('/')) return null;
  const parts = key.split('/');
  if (parts.length < 5) return null;
  if (parts[0] !== 'praxen' || parts[2] !== 'patienten') return null;
  const praxisId = parts[1];
  if (!praxisId || !/^[a-zA-Z0-9_-]+$/.test(praxisId)) return null;
  return praxisId;
}

// --------- Auth Middleware ---------
async function authorize(request, key, cors) {
  const authHeader = request.headers.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return { error: jsonResponse({ error: 'Missing Authorization' }, 401, cors) };
  }
  const idToken = authHeader.substring(7);

  let payload;
  try {
    payload = await verifyFirebaseIdToken(idToken);
  } catch (e) {
    return { error: jsonResponse({ error: 'Invalid token: ' + e.message }, 401, cors) };
  }

  const praxisIdFromPath = extractPraxisId(key);
  if (!praxisIdFromPath) {
    return { error: jsonResponse({ error: 'Invalid path format' }, 400, cors) };
  }

  const userPraxisIds = await getUserPraxisIds(payload.sub, idToken);
  if (!userPraxisIds.includes(praxisIdFromPath)) {
    return { error: jsonResponse({ error: 'Forbidden: praxis access denied' }, 403, cors) };
  }

  return { uid: payload.sub, praxisId: praxisIdFromPath };
}

// --------- Handler ---------
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = corsHeaders(request);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    // Upload: POST /upload?key=path/to/file
    if (request.method === 'POST' && url.pathname === '/upload') {
      const key = url.searchParams.get('key');
      if (!key) return jsonResponse({ error: 'Missing key' }, 400, cors);

      const auth = await authorize(request, key, cors);
      if (auth.error) return auth.error;

      const contentLength = parseInt(request.headers.get('Content-Length') || '0', 10);
      if (contentLength > MAX_UPLOAD_BYTES) {
        return jsonResponse({ error: 'File too large (max 25 MB)' }, 413, cors);
      }

      const body = await request.arrayBuffer();
      if (body.byteLength > MAX_UPLOAD_BYTES) {
        return jsonResponse({ error: 'File too large (max 25 MB)' }, 413, cors);
      }

      const contentType = request.headers.get('Content-Type') || 'application/octet-stream';
      // Whitelist safe content types
      const allowedTypes = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic'];
      const baseType = contentType.split(';')[0].trim().toLowerCase();
      if (!allowedTypes.includes(baseType)) {
        return jsonResponse({ error: 'Content-Type not allowed' }, 415, cors);
      }

      await env.BUCKET.put(key, body, {
        httpMetadata: { contentType: baseType },
        customMetadata: { uid: auth.uid, praxisId: auth.praxisId },
      });

      const fileUrl = `${url.origin}/file/${key}`;
      return jsonResponse({ url: fileUrl, key }, 200, cors);
    }

    // Download: GET /file/path/to/file
    if (request.method === 'GET' && url.pathname.startsWith('/file/')) {
      const key = decodeURIComponent(url.pathname.slice(6));
      const auth = await authorize(request, key, cors);
      if (auth.error) return auth.error;

      const object = await env.BUCKET.get(key);
      if (!object) return jsonResponse({ error: 'Not found' }, 404, cors);

      const headers = new Headers(cors);
      object.writeHttpMetadata(headers);
      headers.set('Cache-Control', 'private, max-age=0, no-store');
      return new Response(object.body, { headers });
    }

    // Delete: DELETE /file/path/to/file
    if (request.method === 'DELETE' && url.pathname.startsWith('/file/')) {
      const key = decodeURIComponent(url.pathname.slice(6));
      const auth = await authorize(request, key, cors);
      if (auth.error) return auth.error;

      await env.BUCKET.delete(key);
      return jsonResponse({ ok: true }, 200, cors);
    }

    return jsonResponse({ service: 'WarteListe Pro R2 API', secure: true }, 200, cors);
  },
};
