import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://stbrhcgzfxvpayfnnqfl.supabase.co';
const supabasePublishableKey = 'sb_publishable_HwBqQzgwWlnRR-tUS9iTUQ_HcZrlsfR';

SupabaseClient get db => Supabase.instance.client;
