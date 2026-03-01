import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/models/profile.dart';

enum AuthAction { idle, signingIn, signingUp, signingInWithGoogle }

class AuthUiState {
  const AuthUiState({
    this.action = AuthAction.idle,
    this.isLoading = false,
    this.errorMessage,
  });

  final AuthAction action;
  final bool isLoading;
  final String? errorMessage;

  AuthUiState copyWith({
    AuthAction? action,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthUiState(
      action: action ?? this.action,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(Supabase.instance.client);
});

// Profile Repository Provider
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

// Auth State Provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user;
});

// Profile Provider
final profileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final repository = ref.watch(profileRepositoryProvider);
  return await repository.getProfile(user.id);
});

// Login Controller
class AuthController extends StateNotifier<AuthUiState> {
  final AuthRepository _repository;
  static const Duration _authTimeout = Duration(seconds: 15);

  AuthController(this._repository) : super(const AuthUiState());

  Future<void> signIn({required String email, required String password}) async {
    await _runAuthAction(
      action: AuthAction.signingIn,
      operation: () => _repository
          .signInWithEmail(email: email, password: password)
          .timeout(_authTimeout),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    await _runAuthAction(
      action: AuthAction.signingUp,
      operation: () => _repository
          .signUpWithEmail(email: email, password: password)
          .timeout(_authTimeout),
    );
  }

  Future<void> signInWithGoogle({required String redirectTo}) async {
    await _runAuthAction(
      action: AuthAction.signingInWithGoogle,
      operation: () => _repository
          .signInWithGoogle(redirectTo: redirectTo)
          .timeout(_authTimeout),
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      debugPrint('[AUTH] signOut started');
      await _repository.signOut();
      state = state.copyWith(isLoading: false, action: AuthAction.idle, clearError: true);
      debugPrint('[AUTH] signOut success');
    } catch (e) {
      final message = _mapAuthError(e);
      state = state.copyWith(
        isLoading: false,
        action: AuthAction.idle,
        errorMessage: message,
      );
      debugPrint('[AUTH] signOut error: $message');
    }
  }

  Future<void> _runAuthAction({
    required AuthAction action,
    required Future<dynamic> Function() operation,
  }) async {
    state = state.copyWith(action: action, isLoading: true, clearError: true);

    final operationName = switch (action) {
      AuthAction.signingIn => 'signIn',
      AuthAction.signingUp => 'signUp',
      AuthAction.signingInWithGoogle => 'signInWithGoogle',
      AuthAction.idle => 'auth',
    };
    debugPrint('[AUTH] $operationName started');
    try {
      await operation();
      state = state.copyWith(action: AuthAction.idle, isLoading: false, clearError: true);
      debugPrint('[AUTH] $operationName success');
    } catch (e) {
      final message = _mapAuthError(e);
      state = state.copyWith(
        action: AuthAction.idle,
        isLoading: false,
        errorMessage: message,
      );
      debugPrint('[AUTH] $operationName error: $message');
    }
  }

  String _mapAuthError(Object error) {
    if (error is TimeoutException) {
      return 'La solicitud tardo demasiado. Intenta de nuevo.';
    }
    if (error is AuthException) {
      final raw = error.message.toLowerCase();
      if (raw.contains('invalid login credentials')) {
        return 'Correo o contrasena incorrectos.';
      }
      if (raw.contains('user already registered')) {
        return 'Ese correo ya esta registrado.';
      }
      if (raw.contains('email not confirmed')) {
        return 'Debes confirmar tu correo antes de iniciar sesion.';
      }
      if (raw.contains('network') || raw.contains('socket') || raw.contains('failed to fetch')) {
        return 'No hay conexion. Revisa internet e intenta de nuevo.';
      }
      return error.message;
    }

    final fallback = error.toString();
    if (fallback.toLowerCase().contains('socket') || fallback.toLowerCase().contains('network')) {
      return 'No hay conexion. Revisa internet e intenta de nuevo.';
    }
    return 'Ocurrio un error inesperado. Intenta de nuevo.';
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>((ref) {
      return AuthController(ref.watch(authRepositoryProvider));
    });
