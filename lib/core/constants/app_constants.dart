import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String _env(String key, {String? fallbackKey}) {
    final primary = dotenv.env[key]?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    if (fallbackKey != null) {
      final fallback = dotenv.env[fallbackKey]?.trim();
      if (fallback != null && fallback.isNotEmpty) return fallback;
    }
    return '';
  }

  // Supabase
  static String get supabaseUrl =>
      _env('PUBLIC_SUPABASE_URL', fallbackKey: 'SUPABASE_URL');
  static String get supabaseAnonKey =>
      _env('PUBLIC_SUPABASE_ANON_KEY', fallbackKey: 'SUPABASE_ANON_KEY');
  
  // Stripe
  static String get stripePublishableKey =>
      _env('PUBLIC_STRIPE_PUBLISHABLE_KEY', fallbackKey: 'STRIPE_PUBLISHABLE_KEY');
  
  // Cloudinary
  static String get cloudinaryCloudName =>
      _env('PUBLIC_CLOUDINARY_CLOUD_NAME', fallbackKey: 'CLOUDINARY_CLOUD_NAME');
  static String get cloudinaryApiKey =>
      _env('PUBLIC_CLOUDINARY_API_KEY', fallbackKey: 'CLOUDINARY_API_KEY');
  static String get siteUrl => _env('PUBLIC_SITE_URL', fallbackKey: 'SITE_URL');
  
  // App
  static const String appName = 'Aurum Fashion Market';
  static const String currency = 'EUR';
}
