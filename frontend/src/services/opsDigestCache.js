// Bedryfsopsomming word daagliks gekas (een per dag) en by mutasies ongeldig gemaak.

const DIGEST_CACHE_PREFIX = 'dashboard_digest_v2_';

// Lokale datum (nie UTC nie) sodat 00:00-02:00 SAST nie in die vorige dag se slot beland nie.
function localDateKey(d = new Date()) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function opsDigestCacheKey() {
  return DIGEST_CACHE_PREFIX + localDateKey();
}

export function readOpsDigestCache() {
  try {
    const raw = localStorage.getItem(opsDigestCacheKey());
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) && parsed.length ? parsed : null;
  } catch {
    return null;
  }
}

export function writeOpsDigestCache(digest) {
  try {
    localStorage.setItem(opsDigestCacheKey(), JSON.stringify(digest));
  } catch {
    // localStorage kan onbeskikbaar wees; caching is beste-poging.
  }
}

export function invalidateOpsDigestCache() {
  try {
    localStorage.removeItem(opsDigestCacheKey());
  } catch {
    // beste-poging
  }
}