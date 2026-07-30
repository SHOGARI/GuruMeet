abstract final class ApiConfig {
  static const String _apiBaseUrl = String.fromEnvironment(
    'GURUMEET_API_BASE_URL',
  );

  static String get apiBaseUrl {
    final value = _apiBaseUrl.trim();
    if (value.isEmpty) {
      throw StateError('GURUMEET_API_BASE_URL must be configured.');
    }
    return value;
  }

  static const String _enableMocks = String.fromEnvironment(
    'GURUMEET_ENABLE_MOCKS',
  );

  static bool get enableMocks {
    return switch (_enableMocks.trim().toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => throw StateError('GURUMEET_ENABLE_MOCKS must be true or false.'),
    };
  }
}
