abstract final class DemoConfig {
  static const bool isDemoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );

  static const String roomCode = 'DEMO';
}
