import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://stbrhcgzfxvpayfnnqfl.supabase.co';
const supabasePublishableKey = 'sb_publishable_HwBqQzgwWlnRR-tUS9iTUQ_HcZrlsfR';

// Preserve the existing Supabase session on upgrade, then keep it encrypted
// by the platform secure store instead of plaintext SharedPreferences.
class LaminAuthLocalStorage extends LocalStorage {
  static const _persistSessionKey = 'sb-stbrhcgzfxvpayfnnqfl-auth-token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  late SharedPreferences _legacyPreferences;

  @override
  Future<void> initialize() async {
    _legacyPreferences = await SharedPreferences.getInstance();
  }

  @override
  Future<bool> hasAccessToken() async {
    if (await _secureStorage.containsKey(key: _persistSessionKey)) return true;
    return _legacyPreferences.containsKey(_persistSessionKey);
  }

  @override
  Future<String?> accessToken() async {
    final secureValue = await _secureStorage.read(key: _persistSessionKey);
    if (secureValue != null) {
      await _legacyPreferences.remove(_persistSessionKey);
      return secureValue;
    }

    final legacyValue = _legacyPreferences.getString(_persistSessionKey);
    if (legacyValue == null) return null;
    await _secureStorage.write(
      key: _persistSessionKey,
      value: legacyValue,
    );
    await _legacyPreferences.remove(_persistSessionKey);
    return legacyValue;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _secureStorage.write(
      key: _persistSessionKey,
      value: persistSessionString,
    );
    await _legacyPreferences.remove(_persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    await _secureStorage.delete(key: _persistSessionKey);
    await _legacyPreferences.remove(_persistSessionKey);
  }
}

SupabaseClient get db => Supabase.instance.client;
