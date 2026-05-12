import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

class MapCacheManager {
  static CacheStore? _store;

  static Future<CacheStore> getCacheStore() async {
    if (_store != null) return _store!;
    
    // Vir nou gebruik ons MemCacheStore om die build te herstel.
    // Vir permanente berging op skyf, kan 'DbCacheStore' gebruik word
    // mits die 'dio_cache_interceptor_db_store' pakket bygevoeg is.
    _store = MemCacheStore();
    return _store!;
  }
}
