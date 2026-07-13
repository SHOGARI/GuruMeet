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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GuruMeet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '今日、どこ食べに行く？',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: 36,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'みんなでスワイプして、行きたい店を決めよう。',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              const HeroCardStack(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(CreateGroupPage.routeName);
                  },
                  child: const Text('グループを作る'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '招待された方は共有されたURLから参加できます',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
