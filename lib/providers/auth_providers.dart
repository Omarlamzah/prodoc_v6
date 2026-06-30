// lib/providers/auth_providers.dart - Complete Fixed Version
import 'dart:io' show Platform, File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../core/network/api_client.dart';
import '../core/utils/result.dart';
import '../data/models/user_model.dart';
import 'api_providers.dart';
import 'tenant_providers.dart';

// Auth State
class AuthState {
  final bool? isAuth;
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  AuthState({
    this.isAuth,
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  AuthState copyWith({
    bool? isAuth,
    UserModel? user,
    String? token,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return AuthState(
      isAuth: isAuth ?? this.isAuth,
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthService(apiClient: apiClient);
});

// Auth State Notifier
class AuthNotifier extends Notifier<AuthState> {
  late AuthService _authService;
  late StorageService _storageService;
  late ApiClient _apiClient;

  @override
  AuthState build() {
    _authService = ref.watch(authServiceProvider);
    _storageService = ref.watch(storageServiceProvider);
    _apiClient = ref.watch(apiClientProvider);

    // Trigger initial check
    Future.microtask(() => _checkAuth());

    return AuthState();
  }

  Future<void> _checkAuth() async {
    // Avoid double loading if already loading
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    final token = await _storageService.getToken();
    if (token != null) {
      _apiClient.setAuthToken(token);
      final result = await _authService.checkAuth();

      if (result is Success<UserModel>) {
        state = state.copyWith(
          isAuth: true,
          user: result.data,
          token: token,
          isLoading: false,
        );
      } else {
        // Token is invalid, clear it but keep remember me if enabled
        await _storageService.saveToken('');
        state = state.copyWith(
          isAuth: false,
          isLoading: false,
        );
      }
    } else {
      // Try auto-login if remember me is enabled
      final rememberMe = await _storageService.getRememberMe();
      if (rememberMe) {
        final savedIdentifier = await _storageService.getSavedIdentifier();
        final savedPassword = await _storageService.getSavedPassword();

        if (savedIdentifier != null && savedPassword != null) {
          // Auto-login with saved credentials (email or phone)
          final isEmail = savedIdentifier.contains('@');
          await login(
            email: isEmail ? savedIdentifier : null,
            phone: isEmail ? null : savedIdentifier,
            password: savedPassword,
            rememberMe: true,
          );
          return;
        }
      }

      state = state.copyWith(
        isAuth: false,
        isLoading: false,
      );
    }
  }

  Future<void> login({
    String? email,
    String? phone,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.login(
      email: email,
      phone: phone,
      password: password,
    );

    if (result is Success<Map<String, dynamic>>) {
      final data = result.data;
      final token = data['token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        await _storageService.saveToken(token);
        _apiClient.setAuthToken(token);

        // Save remember me credentials with whichever identifier was used
        final identifier = email ?? phone ?? '';
        await _storageService.saveRememberMe(rememberMe, identifier, password);

        final user = UserModel.fromJson(userData);
        state = state.copyWith(
          isAuth: true,
          user: user,
          token: token,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid response from server',
        );
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        error: (result as Failure).message,
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? address,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      phone: phone,
      address: address,
    );

    if (result is Success<Map<String, dynamic>>) {
      final data = result.data;
      final token = data['token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (token != null) {
        await _storageService.saveToken(token);
        _apiClient.setAuthToken(token);
      }

      if (userData != null) {
        final user = UserModel.fromJson(userData);
        state = state.copyWith(
          isAuth: true,
          user: user,
          token: token,
          isLoading: false,
          successMessage: 'Registration successful!',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Registration successful! Please login.',
        );
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        error: (result as Failure).message,
      );
    }
  }

  Future<void> registerWithGoogle() async {
    print('[Google Sign-In] ========== Starting Google Sign-In ==========');
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Use Firebase Auth for Google Sign-In
      print('[Google Sign-In] Step 1: Getting Firebase Auth instance');
      final FirebaseAuth auth = FirebaseAuth.instance;
      print('[Google Sign-In] ✓ Firebase Auth instance obtained');

      // In google_sign_in v7.x, use GoogleSignIn.instance singleton
      // and call initialize() before authenticate()
      print('[Google Sign-In] Step 2: Getting GoogleSignIn instance');
      final googleSignIn = GoogleSignIn.instance;
      print('[Google Sign-In] ✓ GoogleSignIn instance obtained');

      // Initialize with serverClientId (Web client ID from google-services.json)
      // This is REQUIRED on Android
      print(
          '[Google Sign-In] Step 3: Initializing GoogleSignIn with serverClientId');
      print(
          '[Google Sign-In] ServerClientId: 1048263640434-3updimfp5414dn6ubphntsstok4gjb1u.apps.googleusercontent.com');
      await googleSignIn.initialize(
        serverClientId:
            '1048263640434-3updimfp5414dn6ubphntsstok4gjb1u.apps.googleusercontent.com',
      );
      print('[Google Sign-In] ✓ GoogleSignIn initialized successfully');

      // Trigger the authentication flow
      print(
          '[Google Sign-In] Step 4: Starting authentication flow (this will show Google sign-in UI)');
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      print('[Google Sign-In] Authentication flow completed');

      if (googleUser == null) {
        // User cancelled the sign-in
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in was cancelled',
        );
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        // accessToken is no longer directly available in GoogleSignInAuthentication in v7
        // and is usually not strictly required for Firebase Auth if idToken is present.
        // If API access is needed, explicit authorization flow is required.
        accessToken: null,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await auth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to authenticate with Google. Please try again.',
        );
        return;
      }

      // Get the Google ID token to send to our backend for verification
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get Google ID token. Please try again.',
        );
        await auth.signOut();
        await googleSignIn.signOut();
        return;
      }

      // Send the raw Google ID token to the backend for server-side verification
      final result = await _authService.register(
        name: firebaseUser.displayName ?? googleUser.displayName ?? 'Google User',
        email: firebaseUser.email ?? '',
        password: 'googleauth',
        passwordConfirmation: 'googleauth',
        additionalData: {
          'google_id_token': idToken,
          'loginbygoogle': true,
        },
      );

      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        final token = data['token'] as String?;
        final userData = data['user'] as Map<String, dynamic>?;

        if (token != null) {
          await _storageService.saveToken(token);
          _apiClient.setAuthToken(token);
        }

        if (userData != null) {
          final user = UserModel.fromJson(userData);
          state = state.copyWith(
            isAuth: true,
            user: user,
            token: token,
            isLoading: false,
            successMessage: 'Google sign-in successful!',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            successMessage: 'Registration successful! Please login.',
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: (result as Failure).message,
        );
        // Sign out from Firebase if backend registration fails
        await auth.signOut();
        await googleSignIn.signOut();
      }
    } catch (e) {
      // Provide more specific error messages
      String errorMessage = 'Google sign-in failed';

      final errorString = e.toString().toLowerCase();

      if (errorString.contains('network_error') ||
          errorString.contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('sign_in_canceled') ||
          errorString.contains('cancelled')) {
        errorMessage = 'Google sign-in was cancelled';
      } else if (errorString
          .contains('account_exists_with_different_credential')) {
        errorMessage =
            'An account already exists with this email. Please use a different sign-in method.';
      } else {
        errorMessage = 'Google sign-in failed: ${e.toString()}';
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );

      try {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  Future<void> registerWithApple() async {
    print('[Apple Sign-In] ========== Starting Apple Sign-In ==========');
    state = state.copyWith(isLoading: true, error: null);

    try {
      // On Android, Apple Sign-In requires web authentication setup
      if (!kIsWeb && Platform.isAndroid) {
        print(
            '[Apple Sign-In] Android platform detected - using web authentication');
      }

      // Check if Apple Sign In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        state = state.copyWith(
          isLoading: false,
          error: 'Apple Sign In is not available on this device',
        );
        return;
      }

      print('[Apple Sign-In] Step 1: Apple Sign In is available');

      // Request Apple Sign In directly (without Firebase)
      print('[Apple Sign-In] Step 2: Requesting Apple authorization');
      print('[Apple Sign-In] This will show the Apple Sign In dialog...');

      final AuthorizationCredentialAppleID appleCredential;
      try {
        // On Android, webAuthenticationOptions is required
        if (!kIsWeb && Platform.isAndroid) {
          appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            webAuthenticationOptions: WebAuthenticationOptions(
              clientId: 'com.nextpital.prodoc', // Your app's bundle ID
              redirectUri: Uri.parse(
                  'https://nextpital.com/callbacks/sign_in_with_apple'),
            ),
          );
        } else {
          // iOS, macOS, or Web
          appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );
        }
        print('[Apple Sign-In] ✓ Apple authorization received');
      } catch (e) {
        print('[Apple Sign-In] Error during Apple authorization: $e');
        final errorString = e.toString();

        // Check if user cancelled
        if (errorString.contains('canceled') ||
            errorString.contains('cancelled') ||
            errorString.contains('user_cancel')) {
          state = state.copyWith(
            isLoading: false,
            error: 'Apple sign-in was cancelled',
          );
          return;
        }

        // Check for error 1000 - Sign in with Apple not configured
        if (errorString.contains('error 1000') ||
            errorString.contains('AuthorizationError error 1000')) {
          state = state.copyWith(
            isLoading: false,
            error:
                'Sign in with Apple is not configured. Please enable it in Xcode: Signing & Capabilities → Add "Sign in with Apple" capability.',
          );
          return;
        }

        // Check for other authorization errors
        if (errorString.contains('SignInWithAppleAuthorizationException') ||
            errorString.contains('AuthorizationError')) {
          state = state.copyWith(
            isLoading: false,
            error:
                'Apple sign-in failed. Please ensure Sign in with Apple is enabled in Xcode and your Apple Developer account.',
          );
          return;
        }

        rethrow;
      }

      // Extract user data from Apple credential
      print('[Apple Sign-In] Step 3: Extracting user information');
      print(
          '[Apple Sign-In] Identity Token: ${appleCredential.identityToken != null ? "present" : "null"}');
      print('[Apple Sign-In] User ID: ${appleCredential.userIdentifier}');

      // Get user information from Apple credential
      String name = '';
      String email = appleCredential.email ?? '';

      // Apple may provide name only on first sign-in
      final givenName = appleCredential.givenName ?? '';
      final familyName = appleCredential.familyName ?? '';
      name = [givenName, familyName].where((n) => n.isNotEmpty).join(' ');

      // Use user identifier if email is not provided (Apple allows users to hide their email)
      final String? userIdentifier = appleCredential.userIdentifier;

      // Validate that we have at least user identifier
      if (userIdentifier == null || userIdentifier.isEmpty) {
        print('[Apple Sign-In] Error: User identifier is null or empty');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get user identifier from Apple. Please try again.',
        );
        return;
      }

      final String finalEmail =
          email.isNotEmpty ? email : '$userIdentifier@privaterelay.appleid.com';

      // Use display name or generate a placeholder
      final String finalName = name.isNotEmpty ? name : 'Apple User';

      print('[Apple Sign-In] Step 4: Registering user with backend');
      print('[Apple Sign-In] Name: $finalName');
      print('[Apple Sign-In] Email: $finalEmail');
      print('[Apple Sign-In] User ID: $userIdentifier');

      // Register user with Apple data in your backend
      final result = await _authService.register(
        name: finalName,
        email: finalEmail,
        password: 'appleauth',
        passwordConfirmation: 'appleauth',
        additionalData: {
          'loginbyapple': true,
          'apple_user_id': userIdentifier,
          'apple_identity_token': appleCredential.identityToken,
        },
      );

      if (result is Success<Map<String, dynamic>>) {
        final data = result.data;
        final token = data['token'] as String?;
        final userData = data['user'] as Map<String, dynamic>?;

        if (token != null) {
          await _storageService.saveToken(token);
          _apiClient.setAuthToken(token);
        }

        if (userData != null) {
          final user = UserModel.fromJson(userData);
          state = state.copyWith(
            isAuth: true,
            user: user,
            token: token,
            isLoading: false,
            successMessage: 'Apple sign-in successful!',
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            successMessage: 'Registration successful! Please login.',
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: (result as Failure).message,
        );
      }
    } catch (e) {
      // Provide more specific error messages
      String errorMessage = 'Apple sign-in failed';

      final errorString = e.toString().toLowerCase();

      if (errorString.contains('network_error') ||
          errorString.contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('canceled') ||
          errorString.contains('cancelled') ||
          errorString.contains('user_cancel')) {
        errorMessage = 'Apple sign-in was cancelled';
      } else if (errorString.contains('error 1000') ||
          errorString.contains('authorizationerror error 1000')) {
        errorMessage =
            'Sign in with Apple is not configured. Please enable it in Xcode: Signing & Capabilities → Add "Sign in with Apple" capability.';
      } else if (errorString.contains('not_handled') ||
          errorString.contains('not available')) {
        errorMessage = 'Apple Sign In is not available on this device';
      } else if (errorString
          .contains('account_exists_with_different_credential')) {
        errorMessage =
            'An account already exists with this email. Please use a different sign-in method.';
      } else if (errorString.contains('authorizationerror')) {
        errorMessage =
            'Apple sign-in configuration error. Please ensure Sign in with Apple is enabled in Xcode and your Apple Developer account.';
      } else {
        errorMessage = 'Apple sign-in failed: ${e.toString()}';
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );

      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.forgotPassword(email);

    if (result is Success<String>) {
      state = state.copyWith(
        isLoading: false,
        successMessage: result.data,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: (result as Failure).message,
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Try to logout from server, but don't fail if it doesn't work
      final result = await _authService.logout();

      // Clear auth-related data but preserve tenant selection
      await _storageService.saveToken('');
      await _storageService.clearRememberMe();
      _apiClient.setAuthToken(null);

      state = AuthState(
        isAuth: false,
        isLoading: false,
        successMessage: result is Success<String> ? (result).data : null,
      );
    } catch (e) {
      // Even if API call fails, clear local state
      await _storageService.saveToken('');
      await _storageService.clearRememberMe();
      _apiClient.setAuthToken(null);

      state = AuthState(
        isAuth: false,
        isLoading: false,
        error: null, // Don't show error to user, just logout locally
      );
    }
  }

  /// Delete (deactivate) the current user's account. On success, logs out locally.
  Future<String?> deleteAccount({required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.deleteAccount(password: password);

    if (result is Success<String>) {
      await _storageService.saveToken('');
      await _storageService.clearRememberMe();
      _apiClient.setAuthToken(null);
      state = AuthState(
        isAuth: false,
        isLoading: false,
        successMessage: result.data,
      );
      return null;
    } else {
      final message = (result as Failure).message;
      state = state.copyWith(isLoading: false, error: message);
      return message;
    }
  }

  void resetError() {
    state = state.copyWith(error: null);
  }

  void resetSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }

  /// Update user profile (name, password, and/or profile image)
  Future<String?> updateProfile({
    String? name,
    String? currentPassword,
    String? newPassword,
    String? passwordConfirmation,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.updateProfile(
      name: name,
      currentPassword: currentPassword,
      newPassword: newPassword,
      passwordConfirmation: passwordConfirmation,
      imageFile: imageFile,
      imageBytes: imageBytes,
      imageFileName: imageFileName,
    );

    if (result is Success<UserModel>) {
      state = state.copyWith(
        user: result.data,
        isLoading: false,
        successMessage: 'Profile updated successfully',
      );
      return null;
    } else {
      final message = (result as Failure).message;
      state = state.copyWith(isLoading: false, error: message);
      return message;
    }
  }
}

// Auth Provider
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
