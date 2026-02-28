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
}
