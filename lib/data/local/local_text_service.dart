import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class LocalTextService {
  static final LocalTextService instance = LocalTextService._();
  LocalTextService._();

  final Map<String, List<String>> _cache = {};

  Future<List<String>> loadTextPool(String lang, String level) async {
    final key = '${lang}_${level}';
    if (_cache.containsKey(key)) return _cache[key]!;
    final jsonStr = await rootBundle.loadString('assets/texts/${lang}_${level}.json');
    final List<dynamic> raw = jsonDecode(jsonStr);
    final texts = raw.cast<String>();
    _cache[key] = texts;
    return texts;
  }

  Future<String> getRandomText(String lang, String level) async {
    final pool = await loadTextPool(lang, level);
    return pool[Random().nextInt(pool.length)];
  }

  // Deterministic text based on date (offline daily fallback)
  // Uses xorshift PRNG for cross-platform consistency
  Future<String> getSeededText(String lang, String level, DateTime date) async {
    final pool = await loadTextPool(lang, level);
    final seedStr = DateFormat('yyyyMMdd').format(date.toUtc());
    int state = int.parse(seedStr);
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    final index = state.abs() % pool.length;
    return pool[index];
  }

  Future<String> getDailyText(String lang, String level, int index) async {
    final jsonStr = await rootBundle.loadString('assets/texts/daily_${lang}_${level}.json');
    final List<dynamic> raw = jsonDecode(jsonStr);
    final item = raw[index % raw.length];
    if (item is Map) return item['text'] as String;
    return item as String;
  }

  void clearCache() => _cache.clear();
}
