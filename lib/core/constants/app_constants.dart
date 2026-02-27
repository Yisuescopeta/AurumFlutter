import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Supabase
  static String get supabaseUrl => dotenv.env['PUBLIC_SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['PUBLIC_SUPABASE_ANON_KEY'] ?? '';
  
  // Stripe
  static String get stripePublishableKey => dotenv.env['PUBLIC_STRIPE_PUBLISHABLE_KEY'] ?? '';
  
  // Cloudinary
  static String get cloudinaryCloudName => dotenv.env['PUBLIC_CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get cloudinaryApiKey => dotenv.env['PUBLIC_CLOUDINARY_API_KEY'] ?? '';
  static String get cloudinaryApiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  
  // App
  static const String appName = 'Aurum Fashion Market';
  static const String currency = 'EUR';
}
