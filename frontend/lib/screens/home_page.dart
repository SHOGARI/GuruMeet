import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/hero_card_stack.dart';
import '../widgets/primary_action_button.dart';
import 'create_group_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isNavigating = false;

  Future<void> _openCreateGroup() async {
    if (_isNavigating) {
      return;
    }
    setState(() => _isNavigating = true);
    await Navigator.of(context).pushNamed(CreateGroupPage.routeName);
    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final headlineStyle = screenWidth < AppBreakpoints.compact
        ? theme.textTheme.headlineLarge
        : theme.textTheme.displaySmall;

    return AppShell(
      maxContentWidth: AppSizes.homeMaxWidth,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.pageEntrance,
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, AppSpacing.regular * (1 - value)),
              child: child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.regular,
                vertical: AppSpacing.small,
              ),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                'GuruMeet',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                  letterSpacing: AppSizes.codeLabelLetterSpacing,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.hero),
            Text('今日、どこ食べに行く？', style: headlineStyle),
            const SizedBox(height: AppSpacing.regular),
            Text(
              'みんなでスワイプして、行きたい店を決めよう。',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.hero),
            const HeroCardStack(),
            const SizedBox(height: AppSpacing.hero),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.actionMaxWidth,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryActionButton(
                      label: 'グループを作る',
                      onPressed: _isNavigating ? null : _openCreateGroup,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    '招待された方は共有されたURLから参加できます',
                    textAlign: TextAlign.left,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
