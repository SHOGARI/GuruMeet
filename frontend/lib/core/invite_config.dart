abstract final class InviteConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'GURUMEET_INVITE_BASE_URL',
  );

  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return _withoutTrailingSlash(configured);
    }

    if (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') {
      return _withoutTrailingSlash(Uri.base.origin);
    }

    throw StateError('GURUMEET_INVITE_BASE_URL must be configured.');
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
