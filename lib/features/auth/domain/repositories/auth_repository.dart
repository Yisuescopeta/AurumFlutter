import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<bool> signInWithGoogle({required String redirectTo});

  Future<void> signOut();

  Future<Session?> get currentSession;

  Stream<AuthState> get authStateChanges;
}
