import 'package:flutter/widgets.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authenticatedChild,
    required this.unauthenticatedChild,
    super.key,
  });

  final Widget authenticatedChild;
  final Widget unauthenticatedChild;

  @override
  Widget build(BuildContext context) {
    // TODO: Switch by Supabase auth session after auth is connected.
    return authenticatedChild;
  }
}
