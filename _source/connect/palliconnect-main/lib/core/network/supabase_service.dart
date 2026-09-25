import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static bool _ready = false;

  /// True once [initialize] has successfully brought up a live client.
  static bool get isReady => _ready;

  static Future<void> initialize() async {
    final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
    final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
    if (url.isEmpty || anonKey.isEmpty) {
      // No credentials bundled — run on the demo catalog.
      return;
    }
    await Supabase.initialize(url: url, anonKey: anonKey);
    _ready = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
