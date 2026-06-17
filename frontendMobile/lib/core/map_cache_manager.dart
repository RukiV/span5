import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

// MapCacheManager: Handles the caching of map tiles to improve performance and reduce data usage.
class MapCacheManager {
  static CacheStore? _store;

  // Returns the cache store, initializing it as a MemCacheStore if not already set.
  static Future<CacheStore> getCacheStore() async {
    if (_store != null) return _store!;
    
    // NOTE: Currently using MemCacheStore for memory-only caching.
    // FUTURE IMPROVEMENT: Switch to 'DbCacheStore' (from dio_cache_interceptor_db_store)
    // for permanent disk-based caching so maps work even after app restarts.
    _store = MemCacheStore();
    return _store!;
  }
}
