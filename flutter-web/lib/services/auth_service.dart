import 'package:flutter/foundation.dart';

/// Authentication service wrapping AWS Cognito.
///
/// In development mode, bypasses authentication entirely.
class AuthService {
  String? _accessToken;
  String? _refreshToken;
  String? _username;
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  String? get username => _username;

  /// Authenticate with username and password via Cognito.
  Future<bool> signIn(String username, String password) async {
    try {
      // TODO: Replace with actual Cognito authentication:
      // final cognitoUser = CognitoUser(username, userPool);
      // final authDetails = AuthenticationDetails(
      //   username: username,
      //   password: password,
      // );
      // final session = await cognitoUser.authenticateUser(authDetails);
      // _accessToken = session.getAccessToken().getJwtToken();
      // _refreshToken = session.getRefreshToken()?.getToken();

      // Development mode: auto-authenticate
      _accessToken = 'dev-token';
      _refreshToken = 'dev-refresh';
      _username = username;
      _isAuthenticated = true;

      debugPrint('Signed in as $username');
      return true;
    } catch (e) {
      debugPrint('Sign in failed: $e');
      _isAuthenticated = false;
      return false;
    }
  }

  /// Refresh the access token using the stored refresh token.
  Future<bool> refreshSession() async {
    if (_refreshToken == null) return false;

    try {
      // TODO: Implement Cognito token refresh
      // final session = await cognitoUser.refreshSession(
      //   CognitoRefreshToken(_refreshToken!),
      // );
      // _accessToken = session.getAccessToken().getJwtToken();
      return true;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      return false;
    }
  }

  /// Sign out and clear all tokens.
  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _username = null;
    _isAuthenticated = false;
  }
}
