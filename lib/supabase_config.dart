import 'package:supabase_flutter/supabase_flutter.dart';

/// Build-time overrides let CI create a trial APK pointed at a separate
/// Supabase project. Existing builds retain the configured production project.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://stbrhcgzfxvpayfnnqfl.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_HwBqQzgwWlnRR-tUS9iTUQ_HcZrlsfR',
);
const isTrialBuild = bool.fromEnvironment('LAMIN_TRIAL_BUILD', defaultValue: false);

SupabaseClient get db => Supabase.instance.client;
