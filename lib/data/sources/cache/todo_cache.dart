import 'package:hive/hive.dart';

class CacheTodoSource {
  Box? _cacheBox;

  Future<void> init() async {
    _cacheBox = await Hive.openBox('cacheBox');
  }

  Future<void> saveCache(String key, dynamic value) async {
    await _cacheBox?.put(key, value);
  }

  dynamic getCache(String key) {
    return _cacheBox?.get(key);
  }

  Future<void> clearCache() async {
    await _cacheBox?.clear();
  }
}