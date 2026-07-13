import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import '../widgets/hero_card_stack.dart';
import 'create_group_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppShell(
      child: Stack(
        children: [
          const Positioned(
            top: 24,
            right: -60,
            child: _AmbientGlow(size: 180, opacity: 0.16),
          ),
          const Positioned(
            left: -40,
            bottom: 120,
            child: _AmbientGlow(size: 140, opacity: 0.1),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'GuruMeet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '今日、どこ\n'),
                        TextSpan(
                          text: '食べに行く？',
                          style: TextStyle(color: colors.primary),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 42,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      'みんなでスワイプして、行きたい店を決めよう。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const HeroCardStack(),
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamed(CreateGroupPage.routeName);
                            },
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            child: const Text('グループを作る'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '招待された方は共有されたURLから参加できます',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF07D57).withValues(alpha: opacity),
        ),
      ),
    );
  }
}
