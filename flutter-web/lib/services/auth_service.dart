import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

/// Authentication service wrapping AWS Cognito.
///
/// Uses Cognito's InitiateAuth API directly via HTTP.
/// In development mode (empty cognitoClientId), bypasses authentication.
class AuthService {
  String? _accessToken;
  String? _refreshToken;
  String? _idToken;
  String? _username;
  bool _isAuthenticated = false;
  Timer? _refreshTimer;

  final Dio _dio = Dio();

  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  String? get idToken => _idToken;
  String? get username => _username;

  bool get _isDevelopment => ApiConfig.cognitoClientId.isEmpty;

  /// Authenticate with username and password via Cognito.
  Future<bool> signIn(String username, String password) async {
    try {
      if (_isDevelopment) {
        _accessToken = 'dev-token';
        _refreshToken = 'dev-refresh';
        _idToken = 'dev-id-token';
        _username = username;
        _isAuthenticated = true;
        debugPrint('Dev mode: signed in as $username');
        return true;
      }

      final response = await _dio.post(
        ApiConfig.cognitoEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/x-amz-json-1.1',
            'X-Amz-Target':
                'AWSCognitoIdentityProviderService.InitiateAuth',
          },
        ),
        data: jsonEncode({
          'AuthFlow': 'USER_PASSWORD_AUTH',
          'ClientId': ApiConfig.cognitoClientId,
          'AuthParameters': {
            'USERNAME': username,
            'PASSWORD': password,
          },
        }),
      );

      final result = response.data['AuthenticationResult'];
      if (result == null) {
        debugPrint('Cognito: unexpected response (challenge required?)');
        return false;
      }

      _accessToken = result['AccessToken'] as String;
      _refreshToken = result['RefreshToken'] as String?;
      _idToken = result['IdToken'] as String?;
      _username = username;
      _isAuthenticated = true;

      _scheduleTokenRefresh(result['ExpiresIn'] as int? ?? 3600);

      debugPrint('Signed in as $username');
      return true;
    } on DioException catch (e) {
      final errorBody = e.response?.data;
      final message = errorBody is Map ? errorBody['message'] : e.message;
      debugPrint('Sign in failed: $message');
      _isAuthenticated = false;
      return false;
    } catch (e) {
      debugPrint('Sign in failed: $e');
      _isAuthenticated = false;
      return false;
    }
  }

  /// Refresh the access token using the stored refresh token.
  Future<bool> refreshSession() async {
    if (_refreshToken == null) return false;

    if (_isDevelopment) return true;

    try {
      final response = await _dio.post(
        ApiConfig.cognitoEndpoint,
        options: Options(
          headers: {
            'Content-Type': 'application/x-amz-json-1.1',
            'X-Amz-Target':
                'AWSCognitoIdentityProviderService.InitiateAuth',
          },
        ),
        data: jsonEncode({
          'AuthFlow': 'REFRESH_TOKEN_AUTH',
          'ClientId': ApiConfig.cognitoClientId,
          'AuthParameters': {
            'REFRESH_TOKEN': _refreshToken,
          },
        }),
      );

      final result = response.data['AuthenticationResult'];
      if (result == null) return false;

      _accessToken = result['AccessToken'] as String;
      _idToken = result['IdToken'] as String?;

      _scheduleTokenRefresh(result['ExpiresIn'] as int? ?? 3600);

      debugPrint('Token refreshed successfully');
      return true;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      _isAuthenticated = false;
      return false;
    }
  }

  /// Sign out and clear all tokens.
  Future<void> signOut() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _accessToken = null;
    _refreshToken = null;
    _idToken = null;
    _username = null;
    _isAuthenticated = false;
  }

  /// Schedule automatic token refresh before expiry.
  void _scheduleTokenRefresh(int expiresInSeconds) {
    _refreshTimer?.cancel();
    // Refresh 5 minutes before expiry.
    final refreshIn = Duration(seconds: expiresInSeconds - 300);
    if (refreshIn.isNegative) return;

    _refreshTimer = Timer(refreshIn, () async {
      await refreshSession();
    });
  }
}
