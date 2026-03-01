/// API configuration for the DocketWatch backend.
class ApiConfig {
  /// Base URL for the Go API server.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Default page size for paginated requests.
  static const int defaultPageSize = 25;

  /// Maximum page size allowed.
  static const int maxPageSize = 100;

  /// Request timeout in seconds.
  static const int timeoutSeconds = 30;

  /// Upload timeout in seconds (for large PDFs).
  static const int uploadTimeoutSeconds = 120;

  /// AWS Cognito configuration.
  static const String cognitoRegion = String.fromEnvironment(
    'COGNITO_REGION',
    defaultValue: 'us-east-1',
  );

  static const String cognitoUserPoolId = String.fromEnvironment(
    'COGNITO_USER_POOL_ID',
    defaultValue: '',
  );

  static const String cognitoClientId = String.fromEnvironment(
    'COGNITO_CLIENT_ID',
    defaultValue: '',
  );

  /// Cognito Identity Provider endpoint.
  static String get cognitoEndpoint =>
      'https://cognito-idp.$cognitoRegion.amazonaws.com/';
}
