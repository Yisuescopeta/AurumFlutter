import 'package:aurum_app/core/constants/app_strings.dart';
import 'package:aurum_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aurum_app/features/auth/presentation/pages/login_screen.dart';
import 'package:aurum_app/features/auth/presentation/pages/register_screen.dart';
import 'package:aurum_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AuthState> get authStateChanges => Stream<AuthState>.empty();

  @override
  Future<Session?> get currentSession async => null;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }
}

class _TestAuthController extends AuthController {
  _TestAuthController({this.onSignUp}) : super(_FakeAuthRepository());

  final Future<void> Function(_TestAuthController controller)? onSignUp;

  @override
  Future<void> signUp({required String email, required String password}) async {
    if (onSignUp != null) {
      await onSignUp!(this);
      return;
    }
    state = const AuthUiState();
  }

  void setAuthState(AuthUiState newState) {
    state = newState;
  }
}

Future<void> _pumpAuthApp(
  WidgetTester tester, {
  required _TestAuthController controller,
  required String initialLocation,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login: crear cuenta abre pantalla de registro', (tester) async {
    await _pumpAuthApp(
      tester,
      controller: _TestAuthController(),
      initialLocation: '/login',
    );

    await tester.tap(find.text(AppStrings.crearCuenta));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ya tienes cuenta'), findsOneWidget);
  });

  testWidgets('register: valida campos antes de registrar', (tester) async {
    await _pumpAuthApp(
      tester,
      controller: _TestAuthController(),
      initialLocation: '/register',
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Introduce tu correo'), findsOneWidget);
    expect(find.text('La contrasena debe tener al menos 6 caracteres'), findsOneWidget);
  });

  testWidgets('register: exito regresa a login', (tester) async {
    await _pumpAuthApp(
      tester,
      controller: _TestAuthController(),
      initialLocation: '/register',
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.bienvenida.toUpperCase()), findsOneWidget);
  });

  testWidgets('register: error muestra snackbar y se queda en registro', (tester) async {
    await _pumpAuthApp(
      tester,
      controller: _TestAuthController(
        onSignUp: (controller) async {
          controller.setAuthState(
            const AuthUiState(errorMessage: 'Ese correo ya esta registrado.'),
          );
        },
      ),
      initialLocation: '/register',
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo crear la cuenta: Ese correo ya esta registrado.'),
      findsOneWidget,
    );
    expect(find.textContaining('Ya tienes cuenta'), findsOneWidget);
  });
}
