abstract final class DemoConfig {
  static const String _isDemoMode = String.fromEnvironment('DEMO_MODE');

  static bool get isDemoMode {
    return switch (_isDemoMode.trim().toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => throw StateError('DEMO_MODE must be true or false.'),
    };
  }

  static const String _roomCode = String.fromEnvironment('DEMO_ROOM_CODE');

  static String get roomCode {
    final value = _roomCode.trim();
    if (value.isEmpty) {
      throw StateError('DEMO_ROOM_CODE must be configured.');
    }
    return value;
  }
}
