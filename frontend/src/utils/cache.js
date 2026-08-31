/**
 * Simple in-memory cache with TTL (Time-To-Live)
 * Used to avoid repeated API calls for expensive operations like predictions
 */

const cache = new Map();
const DEFAULT_TTL = 10 * 60 * 1000; // 10 minutes in milliseconds

/**
 * Get value from cache if not expired
 * @param {string} key - Cache key
 * @returns {any|null} Cached value or null if not found/expired
 */
export function getCache(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  
  const now = Date.now();
  if (now > entry.expiresAt) {
    cache.delete(key);
    return null;
  }
  return entry.value;
}

/**
 * Set value in cache with TTL
 * @param {string} key - Cache key
 * @param {any} value - Value to cache
 * @param {number} ttl - Time to live in milliseconds (default 10 min)
 */
export function setCache(key, value, ttl = DEFAULT_TTL) {
  const expiresAt = Date.now() + ttl;
  cache.set(key, { value, expiresAt });
}

/**
 * Clear specific cache entry
 * @param {string} key - Cache key to clear
 */
export function clearCache(key) {
  cache.delete(key);
}

/**
 * Clear all cache entries
 */
export function clearAllCache() {
  cache.clear();
}

/**
 * Cache wrapper for async functions
 * @param {string} key - Cache key
 * @param {Function} fn - Async function to cache
 * @param {number} ttl - Time to live in milliseconds
 * @returns {Promise<any>} Cached or fresh result
 */
export async function cachedFetch(key, fn, ttl = DEFAULT_TTL) {
  const cached = getCache(key);
  if (cached !== null) {
    return cached;
  }
  
  const result = await fn();
  setCache(key, result, ttl);
  return result;
}

export default {
  get: getCache,
  set: setCache,
  clear: clearCache,
  clearAll: clearAllCache,
  fetch: cachedFetch,
};