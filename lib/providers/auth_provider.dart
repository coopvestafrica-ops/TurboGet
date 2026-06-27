import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Authentication state for the app
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final bool isInitialized;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.isInitialized = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? isInitialized,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isAdmin => user?.isAdmin ?? false;
}

/// Auth state notifier for managing authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);
      await _authService.initialize();
      
      if (_authService.isLoggedIn) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: _authService.currentUser,
          isInitialized: true,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isInitialized: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to initialize authentication',
        isInitialized: true,
      );
    }
  }

  Future<bool> login(String password) async {
    try {
      state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
      
      final success = await _authService.login(password);
      
      if (success) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: _authService.currentUser,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Invalid credentials',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An error occurred during login',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated, isInitialized: true);
  }

  Future<User?> createUser(String? username) async {
    try {
      final user = await _authService.createUser(username);
      return user;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _authService.deleteUser(userId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});

/// Provider for AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

/// Convenience provider for current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// Convenience provider for checking if user is admin
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAdmin;
});

/// Convenience provider for authentication status
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Provider for all registered users (admin only)
final usersProvider = Provider<List<User>>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.isAdmin) {
    return ref.watch(authServiceProvider).users;
  }
  return [];
});
