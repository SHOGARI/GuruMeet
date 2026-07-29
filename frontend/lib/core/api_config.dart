abstract final class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'GURUMEET_API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const bool enableMocks = bool.fromEnvironment(
    'GURUMEET_ENABLE_MOCKS',
    defaultValue: true,
  );
}
