/// The Nuvara Supabase project. Built into the app so every build (APK, web, desktop) works without extra flags;
/// `--dart-define-from-file=.env` can still point a build at a different project.
/// The publishable key is safe to ship; access is enforced by RLS.
const _defaultUrl = 'https://msnpzjuzgfvhcxandhnd.supabase.co';
const _defaultKey = 'sb_publishable_5Usnn52npE9TBGOSaSWBhQ_TCawhuys';

const _envUrl = String.fromEnvironment('SUPABASE_URL');
const _envKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const supabaseUrl = _envUrl == '' ? _defaultUrl : _envUrl;
const supabaseKey = _envKey == '' ? _defaultKey : _envKey;

/// Why the app can't start, or null when the build has its config.
String? get missingConfig => supabaseUrl.isEmpty || supabaseKey.isEmpty
    ? 'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are not set.'
    : null;
